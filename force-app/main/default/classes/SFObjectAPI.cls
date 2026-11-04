public with sharing class SFObjectAPI {

    //###############################################################
    //#
    //# Date: 2 March 2025
    //# Author: ksmeets@salesforc.com
    //# Purpose: Rest Api Sobject interface to query objects in other environments using SOQL
    //#
    //###############################################################

    HttpRequest httpRequest;
    List<Object> urlParams;
    String urlQuery;
    String urlCompositeDelete;
    String urlComposite;

    public class AuthDetails {
        @AuraEnabled
        public string instanceUrl { get; set; }
        @AuraEnabled
        public string accesstoken { get; set; }
        @AuraEnabled
        public string version { get; set; }
        @AuraEnabled
        public boolean authenticated { get; set; }

        public AuthDetails(){
            this.authenticated = false;
            version = 'v62.0';
        }
    }

    //# This connects to the current org; use the other constructor to connect to a specific environment
    public SFObjectAPI() {
     AuthDetails auth = new AuthDetails();

      auth.accesstoken = UserInfo.getSessionId();
      auth.instanceUrl = URL.getOrgDomainUrl().toExternalForm();
      this.initHttpRequest(auth);
    }

    // retrieve the environment from a custom object / custom settings
    public SFObjectAPI(String environment) {      
      //this.initHttpRequest(auth);
    }

    // use a pre-existing auth details object
    public SFObjectAPI(AuthDetails auth) {
      this.initHttpRequest(auth);
    }      
    
    public void initHttpRequest(AuthDetails auth)  {
      this.httpRequest = new HttpRequest();
      this.httpRequest.setHeader('Content-Type', 'application/json;  charset=utf-8');
      this.httpRequest.setHeader('Accept', 'application/json');
      this.httpRequest.setHeader('Authorization', 'Bearer ' + auth.accesstoken);

      this.urlParams = new List<Object>{auth.instanceUrl, auth.version};
      this.urlQuery = string.format('{0}/services/data/{1}/query/?q=', this.urlParams);
      this.urlCompositeDelete = string.format('{0}/services/data/{1}/composite/sobjects?ids=', this.urlParams);
      this.urlComposite = string.format('{0}/services/data/{1}/composite/sobjects/', this.urlParams);
    }

    //### generate a string from a list of values to use with IN operator
    public string createListString(set<string> l) {
      return createListString(new list<string>(l));
    }

    public string createListString(list<string> l) {
      if (l.isEmpty()) { return '(\'\')'; }
      string[] temp = new List<string>(); 
      for (string f : l) { temp.add('\'' + f + '\''); }
      return '(' + string.join(temp, ',') + ')';
    }

    public List<SObject> query(String query) {
        List<SObject> lso = new List<SObject>();
        try {

          String encodedQuery = EncodingUtil.urlEncode(query, 'UTF-8');

          this.httpRequest.setEndpoint(this.urlQuery + encodedQuery);
          system.debug(URL.getOrgDomainUrl());

          system.debug(this.httpRequest.getEndpoint());
          this.httpRequest.setMethod('GET');
          Http http = new Http();

          HttpResponse httpResponse = http.send(httpRequest);
        
          if (httpResponse.getStatusCode() == 200) {
            Map<String, Object> mapResponse = (Map<String, Object>)JSON.deserializeUntyped(httpResponse.getBody());
            List<Object> mapRecords = (List<Object>)mapResponse.get('records');
            Map<string,object> mapRecord = (Map<string,object>) mapRecords.get(0);
            Map<string,object> mapAttributes = (Map<string,object>) mapRecord.get('attributes');
            Type t = Type.forname((String) mapAttributes.get('type'));

            for (Object fRecord : mapRecords) {
              Sobject temp = (Sobject) JSON.deserialize(JSON.serialize(fRecord), t); 
              lso.add(temp);
            }
            
          } else { system.debug(httpResponse.getStatus());
              system.debug(httpResponse.getStatusCode());
              system.debug(httpResponse.getBody());
          }
      }
      catch (Exception e) {
        System.debug(e.getMessage());
      }
      return lso;
    }

    public void del(string[] records) {
        try {
            //this.httpRequest.setEndpoint('callout:AgentCentral/services/data/' + version + '/composite/sobjects?ids=' + string.join(records, ',') + '&allOrNone=true');         
            this.httpRequest.setEndpoint(this.urlCompositeDelete + string.join(records, ',') + '&allOrNone=true');         

            system.debug(this.httpRequest.getEndpoint());
            this.httpRequest.setMethod('DELETE');
            Http http = new Http();

            HttpResponse httpResponse = http.send(httpRequest);
        
            if (httpResponse.getStatusCode() == 200) {
                System.debug('Success 2');
                
            } else {

              httpRequest.setEndpoint(httpResponse.getHeader('Location'));
              new Http().send(httpRequest);    
            }

        } catch (Exception e) {
            
      }   
    }
    public void upd(list<sobject> lso) {
        try{ 

          system.debug(lso[0].get('Id'));
          system.debug(lso[0]);
          
          //string apiURL = this.instanceUrl + '/services/data/' + version + '/composite/sobjects/';
          //this.httpRequest.setEndpoint(apiURL);
          this.httpRequest.setEndpoint(this.urlComposite);         

          string body = buildCompositeCollection(lso);
          system.debug(body);

          httpRequest.setBody(body);

          this.httpRequest.setMethod('PATCH');
          
          // Send the request
          Http http = new Http();
          HttpResponse httpResponse = http.send(httpRequest);
          if (httpResponse.getStatusCode() == 200) {
              System.debug('Success');
              system.debug(httpResponse.getBody());
          } else {
              System.debug(' httpResponse' + httpResponse.getBody());
          }
          } catch (Exception e) {
            System.debug(e.getMessage());
          }
    }

    public void ins(list<sobject> lso) {
        try {
          
          this.httpRequest.setEndpoint(this.urlComposite);         

          string body = buildCompositeCollection(lso);

          httpRequest.setBody(body);

          this.httpRequest.setMethod('POST');
          
          // Send the request
          Http http = new Http();
          HttpResponse httpResponse = http.send(httpRequest);
          if (httpResponse.getStatusCode() == 200) {
              System.debug('Success');
              system.debug(httpResponse.getBody());
          } else {
              System.debug(' httpResponse' + httpResponse.getBody());
          }
          } catch (Exception e) {
            System.debug(e.getMessage());
          }
    }

    private static string buildCompositeCollection(list<sobject> lso) {

      string objectName = lso[0].getSObjectType().getDescribe().getName();
      Map<String, Object> populated = lso[0].getPopulatedFieldsAsMap();
      Set<String> setField = new Set<String>();
      for (String fieldName : populated.keySet()) {
          if (populated.get(fieldName) != null) setField.add(fieldName);
      }

      Map<string,string> mapAttributes = new Map<string,string>{'type' => objectName};
      List<object> mapReqRecords = new List<object>();

      for (integer i = 0; i < lso.size(); i++) {
          Map<string,object> mapReqRecord = new Map<string,object>{'attributes' => mapAttributes};
          Map<String, Object> recordFields = lso[i].getPopulatedFieldsAsMap();
          for (string f : setField) {
            if (recordFields.containsKey(f)) mapReqRecord.put(f, recordFields.get(f));
          }
          system.debug(logginglevel.info, 'record:' + mapReqRecord);
          mapReqRecords.add(mapReqRecord);
      }

      Map<string,object> mapReq = new Map<string,object>{'allOrNone' => true,'records' => mapReqRecords};

      return (string) JSON.serialize(mapReq);
  }


}