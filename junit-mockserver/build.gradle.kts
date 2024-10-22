plugins {
    id("java")
}

group = "ch.fmartin"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.fasterxml.jackson.core:jackson-core:2.18.0")
    implementation("com.fasterxml.jackson.core:jackson-databind:2.18.0")

    testImplementation(platform("org.junit:junit-bom:5.11.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.mock-server:mockserver-junit-jupiter:5.15.0")
    testImplementation("org.slf4j:slf4j-jdk14:2.0.16")
}

tasks.test {
    useJUnitPlatform()
}