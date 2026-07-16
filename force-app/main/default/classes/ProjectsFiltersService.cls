@RestResource(urlMapping='/projectsFilters')
global without sharing class ProjectsFiltersService {

    @HttpGet
    global static void doGet() {

        RestRequest req = RestContext.request;
        String minimalPriceParam = req.params.get('minimalPrice');
        String maximalPriceParam = req.params.get('maximalPrice');
        String projectsParam = req.params.get('projects');
        String districtsParam = req.params.get('districts');
        String typesParam = req.params.get('types');
        String bedroomsParam = req.params.get('bedrooms');
        String statusParam = req.params.get('status');

        List<String> projects = new List<String>();
        List<String> districts = new List<String>();
        List<String> types = new List<String>();
        List<String> bedrooms = new List<String>();
        List<String> status = new List<String>();

        if(projectsParam != null){
            projects = projectsParam.split(',');
        }

        if(districtsParam != null){
            districts = districtsParam.split(',');
        }

        if(typesParam != null){
            types = typesParam.split(',');
        }

        if(bedroomsParam != null){
            bedrooms = bedroomsParam.split(',');
        }

        if(statusParam != null){
            status = statusParam.split(',');
        }

        Map<String, String> queries = buildQueries(minimalPriceParam, maximalPriceParam, projects, districts, types, status, bedrooms);
        String mainQuery = queries.get('mainQuery');
        String mainQueryWithoutMinMaxPrice = queries.get('mainQueryWithoutMinMaxPrice');
        List<Unit__c> unitList = Database.query(mainQuery);
        List<Unit__c> unitListWithoutMinMaxPrice = Database.query(mainQueryWithoutMinMaxPrice);


        Map<String, Object> responseMap = new Map<String, Object>();
        List<Double> prices = new List<Double>();
        for(Unit__c unit : unitListWithoutMinMaxPrice){
            prices.add(unit.Cost_AED__c);
        }
        responseMap.put('quantity', unitList.size());
        responseMap.put('quantity_without_prices', unitListWithoutMinMaxPrice.size());
        responseMap.put('prices', prices);

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseMap));
    }

    private static Map<String, String> buildQueries(String minimalPriceParam, String maximalPriceParam, List<String> projects, List<String> districts, List<String> types, List<String> status, List<String> bedrooms){
        Map<String, String> resultQueries = new Map<String, String>();
        String mainQuery = 'SELECT Id, Cost_AED__c ';
        
        mainQuery += ' FROM Unit__c';
        String whereClause = ' Status__c = \'Published\'';

        if(!projects.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Project__c IN (';
            for(Integer i = 0; i < projects.size(); i++){
                if(i == 0){
                    whereClause += '\'' + projects[i] + '\'';
                } else {
                    whereClause += ',\'' + projects[i] + '\'';

                }
            }
            whereClause += ')';
        }

        if(!districts.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Project__r.District__c IN (';
            for(Integer i = 0; i < districts.size(); i++){
                if(i == 0){
                    whereClause += '\'' + districts[i] + '\'';
                } else {
                    whereClause += ',\'' + districts[i] + '\'';

                }
            }
            whereClause += ')';
        }

        if(!types.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Type__c IN (';
            for(Integer i = 0; i < types.size(); i++){
                if(i == 0){
                    whereClause += '\'' + types[i] + '\'';
                } else {
                    whereClause += ',\'' + types[i] + '\'';

                }
            }
            whereClause += ')';
        }

        if(!status.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Project__r.Project_Status__c IN (';
            for(Integer i = 0; i < status.size(); i++){
                if(i == 0){
                    whereClause += '\'' + status[i] + '\'';
                } else {
                    whereClause += ',\'' + status[i] + '\'';

                }
            }
            whereClause += ')';
        }

        whereClause += ' AND Project__r.Publish_Project__c = \'Published\'';

        if(!bedrooms.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND (';
            }
            Boolean fourOrMore = false;
            if(bedrooms.size() == 1 && bedrooms[0] == '4'){
                whereClause += ' Number_of_Bedrooms__c >= 4';
            } else {
                whereClause += ' Number_of_Bedrooms__c IN (';
                for(Integer i = 0; i < bedrooms.size(); i++){
                    if(i == 0){
                        whereClause += bedrooms[i];
                    } else {
                        whereClause += ',' + bedrooms[i];
    
                    }
                    if(bedrooms[i] == '4'){
                        fourOrMore = true;
                    }
                }
                whereClause += ')';
            }
            if(fourOrMore){
                whereClause += '  OR Number_of_Bedrooms__c >= 4';
            }
            whereClause += ')';
        }

        String whereClauseWithoutMinMaxPrice = whereClause;
        String mainQueryWithoutMinMaxPrice = mainQuery;
        
        if(minimalPriceParam != null){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Unit__c.Cost_AED__c >= ' + minimalPriceParam;
        }

        if(maximalPriceParam != null){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Unit__c.Cost_AED__c <= ' + maximalPriceParam;
        }

        if(whereClause != ''){
            mainQuery += ' WHERE' + whereClause;
            mainQueryWithoutMinMaxPrice  += ' WHERE' + whereClauseWithoutMinMaxPrice;
        }
        mainQuery += ' ORDER BY Cost_AED__c ASC';
        System.debug(mainQuery);
        mainQueryWithoutMinMaxPrice += ' ORDER BY Cost_AED__c ASC';
        resultQueries.put('mainQuery', mainQuery);
        resultQueries.put('mainQueryWithoutMinMaxPrice', mainQueryWithoutMinMaxPrice);
        return resultQueries;
    }
}