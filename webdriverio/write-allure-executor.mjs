import {mkdir, writeFile} from 'node:fs/promises'

const repository = process.env.GITHUB_REPOSITORY
const runNumber = Number(process.env.GITHUB_RUN_NUMBER || 0)
const buildOffset = Number(process.env.ALLURE_BUILD_OFFSET || 0)
const buildOrder = runNumber * 100 + buildOffset
const reportName = runNumber
    ? `CI #${runNumber}${buildOffset ? `.${buildOffset}` : ''}`
    : 'Local report'

let buildUrl
let reportUrl
if (repository) {
    const [owner, name] = repository.split('/')
    buildUrl = `${process.env.GITHUB_SERVER_URL}/${repository}/actions/runs/${process.env.GITHUB_RUN_ID}`
    reportUrl = `https://${owner}.github.io/${name}/`
}

const executor = {
    reportName,
    buildOrder,
    reportUrl,
    name: process.env.GITHUB_ACTIONS === 'true' ? 'GitHub Actions' : 'Local',
    type: 'github',
    buildName: reportName,
    buildUrl,
}

await mkdir('_results_/allure-raw', {recursive: true})
await writeFile(
    '_results_/allure-raw/executor.json',
    `${JSON.stringify(executor, null, 2)}\n`,
)
