package ch.fmartin;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class CompanyRepository {
    List<Company> companies = new ArrayList<>();

    public void add(Company company) {
        companies.add(company);
    }

    public List<Company> findAll() {
        return Collections.unmodifiableList(companies);
    }
}
