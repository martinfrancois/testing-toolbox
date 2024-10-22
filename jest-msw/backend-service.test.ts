import {callBackend} from "./backend-service";
import {setupServer} from "msw/node";
import {http, HttpResponse} from "msw";

describe('Test mocking requests to the backend', () => {
    const server = setupServer(
        http.get('http://localhost:3000/test', () => {
            return HttpResponse.json({expectedKey: "success"});
        })
    );

    beforeAll(() => server.listen());
    afterAll(() => server.close());

    it('should mock the GET /test request', async () => {
        let data = await callBackend();

        // Check if the mocked response was received
        expect(data).toEqual({"expectedKey": "success"});
    });
});
