## Replace PowerMock with Mockito Inline Mocking
> Migrate from PowerMock to Mockito 4+/5+ inline mock maker for Java 11/17 compatibility

### When to Use
- PowerMock tests fail on Java 11+ with `ClassNotFoundException` or bytecode errors
- PowerMock has not been updated for your Java version
- You want to eliminate the PowerMock dependency entirely
- Mocking static methods, constructors, or final classes in MUnit-adjacent Java tests

### Configuration / Code

#### 1. Remove PowerMock Dependencies

```xml
<!-- REMOVE all PowerMock dependencies -->
<!--
<dependency>
    <groupId>org.powermock</groupId>
    <artifactId>powermock-module-junit4</artifactId>
    <version>2.0.9</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.powermock</groupId>
    <artifactId>powermock-api-mockito2</artifactId>
    <version>2.0.9</version>
    <scope>test</scope>
</dependency>
-->
```

#### 2. Add Mockito 5 with Inline Mock Maker

```xml
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-core</artifactId>
    <version>5.11.0</version>
    <scope>test</scope>
</dependency>
<!-- Inline mock maker is default in Mockito 5; for Mockito 4: -->
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-inline</artifactId>
    <version>4.11.0</version>
    <scope>test</scope>
</dependency>
```

#### 3. Replace Static Mocking

```java
// Before (PowerMock)
@RunWith(PowerMockRunner.class)
@PrepareForTest({StaticUtils.class})
public class MyTest {
    @Test
    public void testStaticMethod() {
        PowerMockito.mockStatic(StaticUtils.class);
        when(StaticUtils.getName()).thenReturn("mocked");
        assertEquals("mocked", StaticUtils.getName());
    }
}

// After (Mockito 5)
public class MyTest {
    @Test
    public void testStaticMethod() {
        try (MockedStatic<StaticUtils> mocked = mockStatic(StaticUtils.class)) {
            mocked.when(StaticUtils::getName).thenReturn("mocked");
            assertEquals("mocked", StaticUtils.getName());
        }
        // Static behavior is restored after try-with-resources block
    }
}
```

#### 4. Replace Constructor Mocking

```java
// Before (PowerMock)
@PrepareForTest({HttpClient.class})
public class MyTest {
    @Test
    public void testConstructor() {
        HttpClient mockClient = mock(HttpClient.class);
        PowerMockito.whenNew(HttpClient.class).withNoArguments().thenReturn(mockClient);
    }
}

// After (Mockito 5)
public class MyTest {
    @Test
    public void testConstructor() {
        try (MockedConstruction<HttpClient> mocked = mockConstruction(HttpClient.class)) {
            HttpClient client = new HttpClient();
            // client is automatically mocked
            when(client.execute(any())).thenReturn(mockResponse);
        }
    }
}
```

#### 5. Replace Final Class/Method Mocking

```java
// Before (PowerMock)
@PrepareForTest({FinalClass.class})
// ... PowerMock runner

// After (Mockito 5)
// No special annotation needed — Mockito 5 mocks final classes by default
FinalClass mock = mock(FinalClass.class);
when(mock.finalMethod()).thenReturn("mocked");
```

### How It Works
1. PowerMock uses a custom classloader and bytecode manipulation that conflicts with Java 11+ module system
2. Mockito 4+ introduced `mockito-inline` which uses ByteBuddy's inline mock maker
3. Mockito 5 made inline mock maker the default — no extra dependency needed
4. `MockedStatic` and `MockedConstruction` are scoped to try-with-resources blocks, ensuring cleanup

### Migration Checklist
- [ ] Inventory all `@RunWith(PowerMockRunner.class)` tests
- [ ] Replace `@PrepareForTest` + `PowerMockito.mockStatic()` with `MockedStatic`
- [ ] Replace `PowerMockito.whenNew()` with `MockedConstruction`
- [ ] Remove `@RunWith(PowerMockRunner.class)` — use `@ExtendWith(MockitoExtension.class)` for JUnit 5
- [ ] Remove all `org.powermock` dependencies from POM
- [ ] Run tests on target Java version

### Gotchas
- `MockedStatic` **must** be closed — always use try-with-resources or `@AfterEach` cleanup
- Mockito inline mock maker requires `--add-opens` for Java 17 — see java11-to-17-encapsulation recipe
- PowerMock `@SuppressStaticInitializationFor` has no direct Mockito equivalent — refactor the code instead
- If using JUnit 4, replace `@RunWith(PowerMockRunner.class)` with `@RunWith(MockitoJUnitRunner.class)`
- Mockito 5 requires Java 11+ minimum

### Related
- [java11-to-17-encapsulation](../java11-to-17-encapsulation/) — JVM flags for Mockito inline
- [cglib-to-bytebuddy](../cglib-to-bytebuddy/) — Related bytecode library migration
- [munit2-to-3](../../build-tools/munit2-to-3/) — MUnit test framework migration
