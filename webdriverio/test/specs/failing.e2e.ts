import { expect } from '@wdio/globals'
import LoginPage from '../pageobjects/login.page.js'
import SecurePage from '../pageobjects/secure.page.js'
import {addSeverity} from '@wdio/allure-reporter'

describe('Failing Test Simulation', () => {
    it('should login with valid credentials failing', async () => {
        addSeverity("critical")

        await LoginPage.open()

        // should fail on purpose
        await expect(SecurePage.loginSuccess).toBeExisting()
    })
})

