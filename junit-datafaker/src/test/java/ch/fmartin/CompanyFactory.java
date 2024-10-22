package ch.fmartin;

import net.datafaker.Faker;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class CompanyFactory {

    private static final Faker faker = new Faker();

    public static Company generateRandomCompany(int employeeCount) {
        return new Company(
                faker.idNumber().valid(),
                faker.company().name(),
                faker.company().industry(),
                faker.address().fullAddress(),
                employeeCount,
                EmployeeFactory.generateRandomEmployees(employeeCount),
                generateRandomAdditionalData()
        );
    }

    public static Map<String, String> generateRandomAdditionalData() {
        Map<String, String> additionalData = new HashMap<>();
        additionalData.put("Founded Year", String.valueOf(faker.number().numberBetween(1900, 2023)));
        additionalData.put("CEO", faker.name().fullName());
        return additionalData;
    }

}
