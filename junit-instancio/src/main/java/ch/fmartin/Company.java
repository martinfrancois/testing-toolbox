package ch.fmartin;

import java.util.List;
import java.util.Map;

public record Company(
        long id,
        String companyName,
        String industry,
        String headquartersLocation,
        int numberOfEmployees,
        List<Employee> employees,
        Map<String, String> additionalData // custom fields for further information
) {}