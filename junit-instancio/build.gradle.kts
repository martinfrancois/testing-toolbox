plugins {
    id("java")
}

group = "ch.fmartin"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(platform("org.junit:junit-bom:5.11.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    implementation("org.instancio:instancio-core:5.0.2")
}

tasks.test {
    useJUnitPlatform()
}