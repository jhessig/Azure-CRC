// cypress/integration/visitor_counter_spec.js
describe('Visitor Counter API', () => {
    const API_URL = Cypress.env('API_URL') || 'https://{{API_URL}}/api/visitor_count';

    it('should increment visitor count', () => {
        // Make first request
        cy.request('POST', API_URL)
            .then((response) => {
                expect(response.status).to.eq(200);
                expect(response.body).to.have.property('count');
                expect(response.body.count).to.be.a('number');

                const firstCount = response.body.count;

                // Make second request
                cy.request('POST', API_URL)
                    .then((secondResponse) => {
                        expect(secondResponse.status).to.eq(200);
                        expect(secondResponse.body.count).to.eq(firstCount + 1);
                    });
            });
    });

    it('should handle CORS correctly', () => {
        cy.request('POST', API_URL)
            .then((response) => {
                expect(response.headers).to.have.property('access-control-allow-origin');
            });
    });

    it('should return valid JSON', () => {
        cy.request('POST', API_URL)
            .then((response) => {
                expect(response.body).to.be.an('object');
                expect(response.body.count).to.be.a('number');
                expect(response.body.count).to.be.at.least(1);
            });
    });
});