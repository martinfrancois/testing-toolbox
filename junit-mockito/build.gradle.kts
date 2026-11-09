plugins {
    id("java")
}

group = "ch.fmartin"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

val mockitoVersion = "5.24.0"
// Mockito attaches its Java agent at runtime unless it is passed to the JVM up front.
// JDK 21+ prints a warning for that self-attach and a future JDK will refuse it.
val mockitoAgent = configurations.create("mockitoAgent")

dependencies {
    implementation("com.fasterxml.jackson.core:jackson-core:2.22.4")
    implementation("com.fasterxml.jackson.core:jackson-databind:2.22.4")

    testImplementation(platform("org.junit:junit-bom:6.1.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.mockito:mockito-core:$mockitoVersion")
    testImplementation("org.mockito:mockito-junit-jupiter:$mockitoVersion")
    mockitoAgent("org.mockito:mockito-core:$mockitoVersion") { isTransitive = false }
}

tasks.test {
    useJUnitPlatform()
    // The Mockito agent appends to the boot class path, which makes the JVM warn that class data
    // sharing only covers boot loader classes. Sharing only speeds up JVM startup, so turn it off.
    jvmArgs("-javaagent:${mockitoAgent.asPath}", "-Xshare:off")
}
