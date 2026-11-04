@IsTest
private class SFObjectAPITest {

    private static final String INSTANCE = 'https://example.my.salesforce.com';
    private static final String TOKEN = 'token123';
    private static final String ACCOUNT_ID = '001000000000001AAA';
    private static final String OTHER_ACCOUNT_ID = '001000000000002AAA';

    private class RoutingMock implements HttpCalloutMock {
        private final List<HttpResponse> responses;
        private Integer cursor = 0;
        public Boolean throwOnSend = false;
        public List<HttpRequest> captured = new List<HttpRequest>();

        RoutingMock(List<HttpResponse> responses) {
            this.responses = responses;
        }

        public HttpResponse respond(HttpRequest req) {
            captured.add(req);
            if (throwOnSend) {
                throw new CalloutException('simulated callout failure');
            }
            HttpResponse current = responses[cursor];
            if (cursor < responses.size() - 1) {
                cursor++;
            }
            return current;
        }
    }

    @IsTest
    static void authDetailsDefaultToUnauthenticated() {
        SFObjectAPI.AuthDetails auth = new SFObjectAPI.AuthDetails();

        System.assertEquals(false, auth.authenticated);
        System.assertEquals('v62.0', auth.version);
        System.assertEquals(null, auth.instanceUrl);
        System.assertEquals(null, auth.accesstoken);
    }

    @IsTest
    static void createListStringQuotesValuesForInClause() {
        SFObjectAPI api = client();

        System.assertEquals('(\'\')', api.createListString(new List<String>()));
        System.assertEquals('(\'\')', api.createListString(new Set<String>()));
        System.assertEquals('(\'abc\')', api.createListString(new List<String>{ 'abc' }));
        System.assertEquals('(\'a\',\'b\')', api.createListString(new List<String>{ 'a', 'b' }));

        String fromSet = api.createListString(new Set<String>{ ACCOUNT_ID, OTHER_ACCOUNT_ID });
        System.assert(fromSet.contains('\'' + ACCOUNT_ID + '\''));
        System.assert(fromSet.contains('\'' + OTHER_ACCOUNT_ID + '\''));
        System.assert(fromSet.startsWith('('));
        System.assert(fromSet.endsWith(')'));
    }

    @IsTest
    static void queryReturnsTypedRecords() {
        String body = queryBody(new List<Account>{
            new Account(Id = ACCOUNT_ID, Name = 'Acme'),
            new Account(Id = OTHER_ACCOUNT_ID, Name = 'Globex')
        });
        RoutingMock mock = setMock(new List<HttpResponse>{ httpResponse(200, body, null) });

        Test.startTest();
        List<Account> accounts = (List<Account>) client().query('SELECT Id, Name FROM Account');
        Test.stopTest();

        System.assertEquals(2, accounts.size());
        System.assertEquals(ACCOUNT_ID, accounts[0].Id);
        System.assertEquals('Acme', accounts[0].Name);
        System.assertEquals(OTHER_ACCOUNT_ID, accounts[1].Id);
        System.assertEquals('Globex', accounts[1].Name);
        System.assertEquals('GET', mock.captured[0].getMethod());
        System.assertEquals('Bearer ' + TOKEN, mock.captured[0].getHeader('Authorization'));
        System.assert(mock.captured[0].getEndpoint().startsWith(INSTANCE + '/services/data/v62.0/query/?q='));
        System.assert(mock.captured[0].getEndpoint().contains('Account'));
    }

    @IsTest
    static void queryUsesCurrentOrgSession() {
        RoutingMock mock = setMock(new List<HttpResponse>{
            httpResponse(200, queryBody(new List<Account>{ new Account(Id = ACCOUNT_ID, Name = 'Acme') }), null)
        });

        Test.startTest();
        List<SObject> records = new SFObjectAPI().query('SELECT Id FROM Account');
        Test.stopTest();

        System.assertEquals(1, records.size());
        System.assert(mock.captured[0].getEndpoint().startsWith(URL.getOrgDomainUrl().toExternalForm()));
        System.assert(mock.captured[0].getEndpoint().contains('/services/data/v62.0/query/?q='));
    }

    @IsTest
    static void queryReturnsEmptyWhenCalloutDoesNotSucceed() {
        SFObjectAPI api = client();

        setMock(new List<HttpResponse>{ httpResponse(400, '[{"errorCode":"MALFORMED_QUERY"}]', null) });
        System.assertEquals(0, api.query('SELECT Id FROM Account').size());

        setMock(new List<HttpResponse>{ httpResponse(200, '{"records":[]}', null) });
        System.assertEquals(0, api.query('SELECT Id FROM Account').size());

        setMock(new List<HttpResponse>{ httpResponse(200, '{not-json', null) });
        System.assertEquals(0, api.query('SELECT Id FROM Account').size());

        setMock(new List<HttpResponse>{ httpResponse(200, '{"records":[{"attributes":{"type":"NotARealObject__c"}}]}', null) });
        System.assertEquals(0, api.query('SELECT Id FROM NotARealObject__c').size());

        System.assertEquals(0, new SFObjectAPI('sandbox').query('SELECT Id FROM Account').size());
    }

    @IsTest
    static void deleteSendsCompositeRequest() {
        RoutingMock mock = setMock(new List<HttpResponse>{ httpResponse(200, '[]', null) });

        Test.startTest();
        client().del(new List<String>{ ACCOUNT_ID, OTHER_ACCOUNT_ID });
        Test.stopTest();

        System.assertEquals('DELETE', mock.captured[0].getMethod());
        System.assertEquals(
            INSTANCE + '/services/data/v62.0/composite/sobjects?ids=' + ACCOUNT_ID + ',' + OTHER_ACCOUNT_ID + '&allOrNone=true',
            mock.captured[0].getEndpoint()
        );
    }

    @IsTest
    static void deleteFollowsRedirectWhenDeleteIsNotComplete() {
        RoutingMock mock = setMock(new List<HttpResponse>{
            httpResponse(302, '', INSTANCE + '/services/data/v62.0/composite/sobjects/next'),
            httpResponse(200, '[]', null)
        });

        Test.startTest();
        client().del(new List<String>{ ACCOUNT_ID });
        Test.stopTest();

        System.assertEquals(2, mock.captured.size());
        System.assertEquals(INSTANCE + '/services/data/v62.0/composite/sobjects/next', mock.captured[1].getEndpoint());
    }

    @IsTest
    static void insertPostsCompositeCollection() {
        RoutingMock mock = setMock(new List<HttpResponse>{ httpResponse(200, '[{"success":true}]', null) });
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Alpha'),
            new Account(Name = 'Beta')
        };

        Test.startTest();
        client().ins(accounts);
        Test.stopTest();

        assertCompositeWrite(mock.captured[0], 'POST', new List<String>{ 'Alpha', 'Beta' });
    }

    @IsTest
    static void updatePatchesCompositeCollection() {
        RoutingMock mock = setMock(new List<HttpResponse>{ httpResponse(400, '[{"success":false}]', null) });
        List<Account> accounts = new List<Account>{
            new Account(Id = ACCOUNT_ID, Name = 'Alpha'),
            new Account(Id = OTHER_ACCOUNT_ID, Name = 'Beta')
        };

        Test.startTest();
        client().upd(accounts);
        Test.stopTest();

        assertCompositeWrite(mock.captured[0], 'PATCH', new List<String>{ 'Alpha', 'Beta', ACCOUNT_ID, OTHER_ACCOUNT_ID });
    }

    @IsTest
    static void writeAndDeleteSwallowCalloutFailures() {
        RoutingMock mock = setMock(new List<HttpResponse>());
        mock.throwOnSend = true;
        SFObjectAPI api = client();
        List<Account> accounts = new List<Account>{ new Account(Name = 'Alpha') };

        Test.startTest();
        api.query('SELECT Id FROM Account');
        api.del(new List<String>{ ACCOUNT_ID });
        api.ins(accounts);
        api.upd(accounts);
        api.ins(new List<Account>());
        api.upd(new List<Account>());
        new SFObjectAPI('sandbox').del(new List<String>{ ACCOUNT_ID });
        Test.stopTest();

        System.assertEquals(4, mock.captured.size());
    }

    private static void assertCompositeWrite(HttpRequest request, String method, List<String> expectedValues) {
        System.assertEquals(method, request.getMethod());
        System.assertEquals(INSTANCE + '/services/data/v62.0/composite/sobjects/', request.getEndpoint());
        String body = request.getBody();
        System.assert(body.contains('"allOrNone":true'));
        System.assert(body.contains('"type":"Account"'));
        for (String expectedValue : expectedValues) {
            System.assert(body.contains(expectedValue), 'Body missing ' + expectedValue + ': ' + body);
        }
    }

    private static SFObjectAPI client() {
        SFObjectAPI.AuthDetails auth = new SFObjectAPI.AuthDetails();
        auth.accesstoken = TOKEN;
        auth.instanceUrl = INSTANCE;
        auth.authenticated = true;
        return new SFObjectAPI(auth);
    }

    private static RoutingMock setMock(List<HttpResponse> responses) {
        RoutingMock mock = new RoutingMock(responses);
        Test.setMock(HttpCalloutMock.class, mock);
        return mock;
    }

    private static HttpResponse httpResponse(Integer statusCode, String body, String location) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setStatus(statusCode == 200 ? 'OK' : 'Error');
        response.setBody(body);
        if (location != null) {
            response.setHeader('Location', location);
        }
        return response;
    }

    private static String queryBody(List<Account> accounts) {
        List<Object> records = new List<Object>();
        for (Account account : accounts) {
            records.add(new Map<String, Object>{
                'attributes' => new Map<String, Object>{
                    'type' => 'Account',
                    'url' => '/services/data/v62.0/sobjects/Account/' + account.Id
                },
                'Id' => account.Id,
                'Name' => account.Name
            });
        }
        return JSON.serialize(new Map<String, Object>{
            'totalSize' => accounts.size(),
            'done' => true,
            'records' => records
        });
    }
}
