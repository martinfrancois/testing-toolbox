import { expect } from '@wdio/globals'
import LoginPage from '../pageobjects/login.page.js'
import SecurePage from '../pageobjects/secure.page.js'

describe('Failing Test Simulation', () => {
    it('should login with valid credentials', async () => {
        await LoginPage.open()

        // should fail on purpose
        await expect(SecurePage.loginSuccess).toBeExisting()
    })
})

