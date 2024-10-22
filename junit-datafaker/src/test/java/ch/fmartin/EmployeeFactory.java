package ch.fmartin;

import net.datafaker.Faker;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class EmployeeFactory {

    private static final Faker faker = new Faker();

    public static Employee generateRandomEmployee() {
        return new Employee(
                faker.idNumber().valid(),
                faker.name().firstName(),
                faker.name().lastName(),
                faker.job().position(),
                faker.company().industry(),
                faker.number().randomDouble(2, 40000, 150000),
                generateRandomAttributes()
        );
    }

    public static List<Employee> generateRandomEmployees(int count) {
        List<Employee> employees = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            employees.add(generateRandomEmployee());
        }
        return employees;
    }

    private static Map<String, String> generateRandomAttributes() {
        Map<String, String> attributes = new HashMap<>();
        attributes.put("Language", faker.programmingLanguage().name());
        attributes.put("Favorite Color", faker.color().name());
        return attributes;
    }

}
