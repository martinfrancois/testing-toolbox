package ch.fmartin;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

public class PersonRepository {
    private List<Person> people = Arrays.asList(
            new Person("James", "Smit", "Las Vegas"),
            new Person("Mary", "Miller", "Las Vegas"),
            new Person("John", "Doe", "New York")
    );

    public List<Person> getPeopleBornIn(String city) {
        return people.stream()
                .filter(person -> person.cityOfBirth().equals(city))
                .collect(Collectors.toList());
    }
}

