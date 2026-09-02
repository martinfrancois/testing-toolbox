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

dependencies {
    implementation("com.fasterxml.jackson.core:jackson-core:2.22.2")
    implementation("com.fasterxml.jackson.core:jackson-databind:2.22.2")

    testImplementation(platform("org.junit:junit-bom:6.1.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.mock-server:mockserver-junit-jupiter:7.6.0")
    testImplementation("org.slf4j:slf4j-jdk14:2.0.18")
}

tasks.test {
    useJUnitPlatform()
    // MockServer's Netty loads native libraries; JDK 24+ warns about that unless native access is granted.
    jvmArgs("--enable-native-access=ALL-UNNAMED")
}
