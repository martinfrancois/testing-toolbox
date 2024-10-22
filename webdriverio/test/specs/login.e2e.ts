import { expect } from '@wdio/globals'
import LoginPage from '../pageobjects/login.page.js'
import SecurePage from '../pageobjects/secure.page.js'

describe('Login', () => {
    it('should login with valid credentials', async () => {
        await LoginPage.open()

        await LoginPage.login('student', 'Password123')
        await expect(SecurePage.loginSuccess).toBeExisting()
        await expect(SecurePage.loginSuccess).toHaveText(expect.stringContaining('Logged In Successfully'));
    })
})

