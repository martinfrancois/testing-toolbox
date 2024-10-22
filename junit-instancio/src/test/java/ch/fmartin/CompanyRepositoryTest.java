package ch.fmartin;

import org.instancio.Instancio;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CompanyRepositoryTest {

    @Test
    void add() {
        // given
        CompanyRepository repo = new CompanyRepository();
        Company company = Instancio.create(Company.class);

        // when
        repo.add(company);

        // then
        List<Company> companies = repo.findAll();
        Company actualCompany = companies.get(0);
        assertEquals(company, actualCompany);
    }
}