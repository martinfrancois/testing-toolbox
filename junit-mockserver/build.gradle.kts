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
    implementation("com.fasterxml.jackson.core:jackson-core:2.22.4")
    implementation("com.fasterxml.jackson.core:jackson-databind:2.22.4")

    testImplementation(platform("org.junit:junit-bom:6.1.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.mock-server:mockserver-junit-jupiter:9.1.0")
    testImplementation("org.slf4j:slf4j-jdk14:2.0.20")

    constraints {
        // MockServer brings Jackson 3.2.1 with known CVEs; drop once it brings 3.2.3, see https://github.com/martinfrancois/testing-toolbox/issues/70
        testImplementation("tools.jackson:jackson-bom:3.2.4")
    }
}

tasks.test {
    useJUnitPlatform()
    // MockServer's Netty loads native libraries; JDK 24+ warns about that unless native access is granted.
    jvmArgs("--enable-native-access=ALL-UNNAMED")
}
