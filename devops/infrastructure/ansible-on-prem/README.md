## Ansible for On-Prem Mule Runtime
> Ansible playbooks for installing, configuring, and managing on-premise Mule runtimes

### When to Use
- You run Mule runtimes on-premise (bare metal or VMs)
- You need automated, repeatable runtime installation and patching
- You want configuration management for multiple Mule server groups

### Configuration

**inventory/hosts.yml**
```yaml
all:
  vars:
    mule_version: "4.6.4"
    mule_home: "/opt/mule"
    java_home: "/usr/lib/jvm/java-17-openjdk"
    anypoint_region: "us-east-1"

  children:
    mule_dev:
      hosts:
        mule-dev-01:
          ansible_host: 10.0.1.10
        mule-dev-02:
          ansible_host: 10.0.1.11

    mule_prod:
      hosts:
        mule-prod-01:
          ansible_host: 10.0.2.10
        mule-prod-02:
          ansible_host: 10.0.2.11
        mule-prod-03:
          ansible_host: 10.0.2.12
      vars:
        mule_heap_min: "2g"
        mule_heap_max: "4g"
```

**playbooks/install-runtime.yml**
```yaml
---
- name: Install Mule Runtime
  hosts: all
  become: true
  vars:
    mule_installer: "mule-ee-distribution-standalone-{{ mule_version }}.tar.gz"
    mule_download_url: "https://repository.mulesoft.org/nexus/content/repositories/releases/com/mulesoft/muleesb/{{ mule_version }}/{{ mule_installer }}"

  tasks:
    - name: Ensure Java 17 is installed
      package:
        name: java-17-openjdk
        state: present

    - name: Create mule user
      user:
        name: mule
        system: true
        shell: /sbin/nologin
        home: "{{ mule_home }}"

    - name: Create Mule directory
      file:
        path: "{{ mule_home }}"
        state: directory
        owner: mule
        group: mule
        mode: "0755"

    - name: Download Mule runtime
      get_url:
        url: "{{ mule_download_url }}"
        dest: "/tmp/{{ mule_installer }}"
        headers:
          Authorization: "Bearer {{ nexus_token }}"

    - name: Extract Mule runtime
      unarchive:
        src: "/tmp/{{ mule_installer }}"
        dest: "{{ mule_home }}"
        remote_src: true
        owner: mule
        group: mule
        extra_opts: [--strip-components=1]

    - name: Configure JVM heap
      template:
        src: templates/wrapper.conf.j2
        dest: "{{ mule_home }}/conf/wrapper.conf"
        owner: mule
        group: mule
      notify: Restart Mule

    - name: Register with Anypoint
      command: >
        {{ mule_home }}/bin/amc_setup -H {{ anypoint_token }}
        {{ mule_home }}
      become_user: mule
      when: anypoint_token is defined

    - name: Install systemd service
      template:
        src: templates/mule.service.j2
        dest: /etc/systemd/system/mule.service
      notify:
        - Reload systemd
        - Restart Mule

    - name: Enable and start Mule
      systemd:
        name: mule
        enabled: true
        state: started

  handlers:
    - name: Reload systemd
      systemd:
        daemon_reload: true

    - name: Restart Mule
      systemd:
        name: mule
        state: restarted
```

**templates/mule.service.j2**
```ini
[Unit]
Description=MuleSoft Runtime {{ mule_version }}
After=network.target

[Service]
Type=forking
User=mule
Group=mule
Environment="JAVA_HOME={{ java_home }}"
Environment="MULE_HOME={{ mule_home }}"
ExecStart={{ mule_home }}/bin/mule start
ExecStop={{ mule_home }}/bin/mule stop
ExecReload={{ mule_home }}/bin/mule restart
Restart=on-failure
RestartSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

**templates/wrapper.conf.j2**
```properties
wrapper.java.additional.4=-Xms{{ mule_heap_min | default('1g') }}
wrapper.java.additional.5=-Xmx{{ mule_heap_max | default('2g') }}
wrapper.java.additional.6=-XX:+UseG1GC
wrapper.java.additional.7=-XX:MaxGCPauseMillis=200
wrapper.java.additional.8=-Djava.net.preferIPv4Stack=true
```

### How It Works
1. The inventory defines server groups (dev, prod) with per-group JVM tuning
2. The playbook installs Java 17, downloads Mule EE from a private Nexus repo, and extracts it
3. JVM settings are templated via Jinja2 with sensible defaults
4. A systemd service ensures Mule starts on boot and restarts on failure
5. Anypoint registration uses the `amc_setup` tool with a one-time token

### Gotchas
- Mule EE requires a license; the Nexus download URL requires authentication
- `amc_setup` tokens expire quickly; generate them just before running the playbook
- JVM heap should not exceed 50-70% of available RAM to leave room for metaspace and OS
- On-prem servers need outbound HTTPS to `anypoint.mulesoft.com` for management plane
- Ansible `become: true` requires passwordless sudo or `-K` flag for the mule user

### Related
- [terraform-anypoint](../terraform-anypoint/) — Manage Anypoint config as code
- [helm-rtf](../helm-rtf/) — RTF deployment (container-based alternative)
- [monitoring-telemetry](../../monitoring-telemetry/) — Monitor on-prem runtimes
