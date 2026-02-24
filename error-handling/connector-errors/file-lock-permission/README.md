## File Lock and Permission Errors
> Handle FILE:ACCESS_DENIED and FILE:FILE_LOCK with retry for locks and clear errors for permissions.

### When to Use
- File-based integrations where files may be locked by other processes
- SFTP/FTP operations where permissions vary
- You need to distinguish between temporary locks and permanent permission errors

### Configuration / Code

```xml
<flow name="file-reader-flow">
    <scheduler>
        <scheduling-strategy><fixed-frequency frequency="60000"/></scheduling-strategy>
    </scheduler>
    <try>
        <file:list config-ref="File_Config" directoryPath="${file.input.dir}"/>
        <foreach>
            <try>
                <file:read config-ref="File_Config" path="#[attributes.path]"/>
                <flow-ref name="process-file"/>
                <file:delete config-ref="File_Config" path="#[attributes.path]"/>
                <error-handler>
                    <on-error-continue type="FILE:FILE_LOCK">
                        <logger level="WARN" message="File locked, will retry next poll: #[attributes.fileName]"/>
                    </on-error-continue>
                    <on-error-propagate type="FILE:ACCESS_DENIED">
                        <logger level="ERROR" message="Permission denied for file: #[attributes.fileName]"/>
                        <raise-error type="APP:PERMISSION_ERROR"
                                     description="Cannot read file: #[attributes.fileName]"/>
                    </on-error-propagate>
                </error-handler>
            </try>
        </foreach>
    </try>
</flow>
```

### How It Works
1. `FILE:FILE_LOCK` — file is temporarily locked by another process; `on-error-continue` skips it (retried next poll)
2. `FILE:ACCESS_DENIED` — permanent permission issue; `on-error-propagate` raises an alert
3. Scheduler retries locked files on the next poll cycle
4. Permission errors need human intervention

### Gotchas
- File locks on NFS/CIFS may not be detected by the File connector — test with your filesystem
- SFTP uses `SFTP:ACCESS_DENIED`, not `FILE:ACCESS_DENIED` — match the right connector type
- `file:delete` after processing prevents reprocessing; use idempotent filter if delete fails

### Related
- [Until Successful Basic](../../retry/until-successful-basic/) — retry locked file immediately
- [Reconnection Strategy](../../retry/reconnection-strategy/) — SFTP connection recovery
