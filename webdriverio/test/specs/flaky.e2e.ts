import { expect } from '@wdio/globals'
import LoginPage from '../pageobjects/login.page.js'
import SecurePage from '../pageobjects/secure.page.js'

describe('Flaky Test Simulation', () => {
    it('should login with valid credentials sometimes', async () => {
        await LoginPage.open()

        await LoginPage.login('student', 'Password123')
        await expect(SecurePage.loginSuccess).toBeExisting()
        await expect(SecurePage.loginSuccess).toHaveText(
            'Logged In Successfully')

        const randomFail = Math.random() > 0.4; // 60% chance of failing the test
        if (randomFail) {
            // Test fails with random chance
            fail('Random failure triggered');
        }
    })
})

