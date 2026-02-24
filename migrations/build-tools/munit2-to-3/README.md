## MUnit 2.x to 3.x Test Migration
> Migrate MUnit test framework from 2.x to 3.x for Mule 4.6+ compatibility

### When to Use
- Upgrading to Mule 4.6+ which requires MUnit 3.x
- MUnit 2.x tests fail on newer runtime versions
- Need Java 17 compatibility for test execution

### Configuration / Code

#### 1. POM Dependency Update

```xml
<!-- Before: MUnit 2.x -->
<dependency>
    <groupId>com.mulesoft.munit</groupId>
    <artifactId>munit-runner</artifactId>
    <version>2.3.17</version>
    <classifier>mule-plugin</classifier>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>com.mulesoft.munit</groupId>
    <artifactId>munit-tools</artifactId>
    <version>2.3.17</version>
    <classifier>mule-plugin</classifier>
    <scope>test</scope>
</dependency>

<!-- After: MUnit 3.x -->
<dependency>
    <groupId>com.mulesoft.munit</groupId>
    <artifactId>munit-runner</artifactId>
    <version>3.2.0</version>
    <classifier>mule-plugin</classifier>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>com.mulesoft.munit</groupId>
    <artifactId>munit-tools</artifactId>
    <version>3.2.0</version>
    <classifier>mule-plugin</classifier>
    <scope>test</scope>
</dependency>
```

#### 2. Maven Plugin Update

```xml
<plugin>
    <groupId>com.mulesoft.munit.tools</groupId>
    <artifactId>munit-maven-plugin</artifactId>
    <version>3.2.0</version>
    <configuration>
        <runtimeVersion>4.6.0</runtimeVersion>
        <argLine>
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
        </argLine>
    </configuration>
</plugin>
```

#### 3. Test XML Changes

```xml
<!-- MUnit 2.x test -->
<munit:test name="test-order-flow"
    description="Test order processing">
    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="config-ref" whereValue="HTTP_Config" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[{"status": "ok"}]'
                    mediaType="application/json" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="orderProcessingFlow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('ok')]" />
    </munit:validation>
</munit:test>

<!-- MUnit 3.x test (mostly compatible, with additions) -->
<munit:test name="test-order-flow"
    description="Test order processing"
    tags="integration,orders">
    <!-- Same structure; new features available -->
    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="config-ref" whereValue="HTTP_Config" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[{"status": "ok"}]'
                    mediaType="application/json" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="orderProcessingFlow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('ok')]" />
    </munit:validation>
</munit:test>
```

### How It Works
1. MUnit 3.x aligns with Mule 4.6+ runtime internals
2. Test XML syntax is largely backward compatible with 2.x
3. Java 17 requires `--add-opens` JVM flags for test execution
4. New features include test tags, improved assertions, and better reporting

### Migration Checklist
- [ ] Update MUnit dependencies to 3.x in POM
- [ ] Update MUnit Maven plugin to 3.x
- [ ] Add `--add-opens` argLine for Java 17
- [ ] Run all existing tests to verify compatibility
- [ ] Fix any tests using deprecated MUnit 2.x features
- [ ] Update CI/CD to use MUnit 3.x reporting format

### Gotchas
- Most MUnit 2.x tests work without changes on 3.x
- Some internal assertion class names may have changed
- Test report format may differ (update CI reporting plugins)
- MUnit 3.x requires Mule 4.6+ runtime; cannot test on older runtimes
- `--add-opens` is required for Java 17 test execution

### Related
- [mule44-to-46](../../runtime-upgrades/mule44-to-46/) - Runtime upgrade
- [mule46-to-49](../../runtime-upgrades/mule46-to-49/) - Runtime upgrade
- [powermock-to-mockito](../../java-versions/powermock-to-mockito/) - Test framework
