// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

        SFObjectAPI api = new SFObjectAPI();
        Account account = [SELECT Id, Name FROM Account LIMIT 1];
        system.debug(logginglevel.info, account.Name);
        account.Name = 'Account Renamed';
        api.upd(new List<Account>{ account });
        System.debug('Done!');