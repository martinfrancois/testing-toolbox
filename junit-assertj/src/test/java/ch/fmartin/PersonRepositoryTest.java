package ch.fmartin;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

class PersonRepositoryTest {
    @Test
    public void getPeopleBornIn() {
        // given
        PersonRepository repo = new PersonRepository();

        // when
        List<Person> people = repo.getPeopleBornIn("Las Vegas");

        // then
        assertThat(people)
                .extracting(Person::firstName, Person::lastName)
                .containsExactlyInAnyOrder(
                        tuple("James", "Smith"),
                        tuple("Mary", "Miller")
                );
    }
}