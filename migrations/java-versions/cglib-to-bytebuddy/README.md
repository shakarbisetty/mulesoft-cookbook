## Replace CGLIB Proxies with ByteBuddy
> Migrate from CGLIB to ByteBuddy for dynamic proxy generation compatible with Java 11/17

### When to Use
- CGLIB-based code fails on Java 17 with `InaccessibleObjectException`
- Custom Mule modules use CGLIB for AOP or proxy generation
- Spring-based custom components (Spring 6+ uses ByteBuddy by default)
- `cglib-nodep` dependency causes classpath conflicts with Mule runtime

### Configuration / Code

#### 1. Replace CGLIB Dependency

```xml
<!-- REMOVE -->
<!--
<dependency>
    <groupId>cglib</groupId>
    <artifactId>cglib-nodep</artifactId>
    <version>3.3.0</version>
</dependency>
-->

<!-- ADD -->
<dependency>
    <groupId>net.bytebuddy</groupId>
    <artifactId>byte-buddy</artifactId>
    <version>1.14.18</version>
</dependency>
```

#### 2. Replace CGLIB Enhancer with ByteBuddy

```java
// Before (CGLIB)
import net.sf.cglib.proxy.Enhancer;
import net.sf.cglib.proxy.MethodInterceptor;

Enhancer enhancer = new Enhancer();
enhancer.setSuperclass(MyService.class);
enhancer.setCallback((MethodInterceptor) (obj, method, args, proxy) -> {
    System.out.println("Before: " + method.getName());
    Object result = proxy.invokeSuper(obj, args);
    System.out.println("After: " + method.getName());
    return result;
});
MyService proxy = (MyService) enhancer.create();

// After (ByteBuddy)
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.implementation.MethodDelegation;
import net.bytebuddy.implementation.bind.annotation.*;
import net.bytebuddy.matcher.ElementMatchers;

MyService proxy = new ByteBuddy()
    .subclass(MyService.class)
    .method(ElementMatchers.any())
    .intercept(MethodDelegation.to(new MyInterceptor()))
    .make()
    .load(MyService.class.getClassLoader())
    .getLoaded()
    .getDeclaredConstructor()
    .newInstance();

public class MyInterceptor {
    @RuntimeType
    public Object intercept(@SuperCall Callable<?> superCall,
                            @Origin Method method) throws Exception {
        System.out.println("Before: " + method.getName());
        Object result = superCall.call();
        System.out.println("After: " + method.getName());
        return result;
    }
}
```

#### 3. Replace CGLIB LazyLoader

```java
// Before (CGLIB)
import net.sf.cglib.proxy.LazyLoader;

Object lazy = Enhancer.create(MyService.class, (LazyLoader) () -> {
    return expensiveInit();
});

// After (ByteBuddy)
// Use standard Java Supplier + lazy initialization pattern
import java.util.function.Supplier;

public class LazyProxy<T> implements Supplier<T> {
    private volatile T instance;
    private final Supplier<T> factory;

    public LazyProxy(Supplier<T> factory) { this.factory = factory; }

    public T get() {
        if (instance == null) {
            synchronized (this) {
                if (instance == null) instance = factory.get();
            }
        }
        return instance;
    }
}
```

### How It Works
1. CGLIB generates proxy classes by subclassing at the bytecode level using ASM
2. Java 17 strong encapsulation breaks CGLIB's access to internal JDK classes
3. ByteBuddy is Java 17-native and the modern standard for bytecode generation
4. Spring 6, Hibernate 6, and Mockito 4+ all migrated from CGLIB to ByteBuddy

### Migration Checklist
- [ ] Search for `net.sf.cglib` and `cglib` imports across all custom Java code
- [ ] Replace `Enhancer` usage with ByteBuddy subclass approach
- [ ] Replace `MethodInterceptor` callbacks with `MethodDelegation`
- [ ] Replace `LazyLoader` with standard Java lazy patterns
- [ ] Remove `cglib`/`cglib-nodep` from POM
- [ ] Test all proxy-dependent functionality

### Gotchas
- ByteBuddy API is more verbose than CGLIB but more type-safe
- ByteBuddy requires the target class to have a no-arg constructor (same as CGLIB)
- If using `Enhancer.create(interfaces)`, switch to `ByteBuddy.subclass(Object.class).implement(interfaces)`
- ByteBuddy class loading requires careful classloader selection in Mule's hierarchical classloader model
- Performance: ByteBuddy-generated proxies are comparable to CGLIB in throughput

### Related
- [java11-to-17-encapsulation](../java11-to-17-encapsulation/) — Strong encapsulation context
- [powermock-to-mockito](../powermock-to-mockito/) — Mockito uses ByteBuddy internally
- [custom-connector-java17](../../connectors/custom-connector-java17/) — Custom connector migration
