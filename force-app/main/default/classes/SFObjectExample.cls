public with sharing class SFObjectExample {
    public SFObjectExample() {

    }

    public void runExample() {
        SFObjectAPI api = new SFObjectAPI();


        Account account = [SELECT Id, Name FROM Account LIMIT 1];
        system.debug(logginglevel.info, account.Name);
        account.Name = 'Account Renamed';
system.debug(logginglevel.info, account.Name);

//api.upd(new List<Account>{ account });
     
        string  query = 'SELECT Id,Name ';
        query+= 'FROM Account ';
        query+= 'LIMIT 10';

        SFObjectAPI sfObjectAPI = new SFObjectAPI();
        List<Account> lsoAccount = (List<Account>) sfObjectAPI.query(query);

        Set<String> setAccountId = new Set<String>();
        for(Account f: lsoAccount) {
            
            setAccountId.add(f.Id);

            system.debug(f.Id);
          }

        query = 'SELECT Id, Name ';
        query+= 'FROM Opportunity ';
        query+= 'WHERE AccountId IN ' + sfObjectAPI.createListString(setAccountId) + ' ';
        query+= 'LIMIT 10';

        List<Opportunity> lsoOpportunity = (List<Opportunity>) sfObjectAPI.query(query);

        for (Opportunity o: lsoOpportunity) {
            system.debug(o.Id);
            system.debug(o.Name);
        }
     
    }
}