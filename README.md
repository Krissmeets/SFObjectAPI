# SFObjectAPI

Apex client for the Salesforce REST API. It runs SOQL and inserts, updates, and deletes sObjects in the current org or in another org.

`SFObjectAPI` builds one authenticated HTTP request, then calls the query and composite sObject resources. `SFObjectExample` shows a query that loads Accounts and the related Opportunities.

## Connect

Use the current user's session to call the org where the code is running:

```apex
SFObjectAPI api = new SFObjectAPI();
```

Pass an access token to call another org. `version` defaults to `v62.0`.

```apex
SFObjectAPI.AuthDetails auth = new SFObjectAPI.AuthDetails();
auth.instanceUrl = 'https://mycompany.my.salesforce.com';
auth.accesstoken = '00D...';
SFObjectAPI api = new SFObjectAPI(auth);
```

Add the target org's domain as a Remote Site Setting. The callout goes to `{instanceUrl}/services/data/{version}/`.

`new SFObjectAPI(environmentName)` does not connect yet. Use one of the constructors above.

## Query

`query` returns the REST records as sObjects. Cast the list to the type you queried.

```apex
List<Account> accounts = (List<Account>) api.query(
    'SELECT Id, Name FROM Account LIMIT 10'
);
```

`createListString` turns ids into a quoted list for a SOQL `IN` clause. An empty list becomes `('')`.

```apex
Set<String> accountIds = new Set<String>();
for (Account account : accounts) {
    accountIds.add(account.Id);
}

String soql = 'SELECT Id, Name FROM Opportunity WHERE AccountId IN '
    + api.createListString(accountIds)
    + ' LIMIT 10';
List<Opportunity> opportunities = (List<Opportunity>) api.query(soql);
```

The same flow is in `SFObjectExample.runExample()`.

## Insert, update, and delete

Insert and update use the composite sObject collection, with `allOrNone` set to true. Only fields populated on the first record are sent. `ins`, `upd`, and `del` each send one request, and that API accepts at most 200 records. A larger list is not split, so Salesforce rejects the whole call.

```apex
api.ins(new List<Account>{
    new Account(Name = 'Alpha'),
    new Account(Name = 'Beta')
});

api.upd(new List<Account>{
    new Account(Id = accountId, Name = 'Renamed')
});

api.del(new List<String>{ accountId });
```

## Deploy and test

```bash
sf project deploy start \
  --metadata ApexClass:SFObjectAPI \
  --metadata ApexClass:SFObjectAPITest \
  --metadata ApexClass:SFObjectExample

sf apex run test --tests SFObjectAPITest --result-format human --synchronous
```

Failed callouts are caught inside the client. `query` then returns an empty list, and the write methods return without an error.
