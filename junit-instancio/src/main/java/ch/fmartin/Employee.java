package ch.fmartin;

import java.util.Map;

public record Employee(
        long id,
        String firstName,
        String lastName,
        String position,
        String department,
        double salary,
        Map<String, String> attributes // additional custom attributes
) {}