public class UnitWrapper {
    public List<PaymentPlanWrapper> fpwrapper {get; set;}
    public List<PaymentPlanWrapper> rpwrapper {get; set;}
    public Set<String> imageUrlToStyleKeySet {get; set;}
    public Map<String, String> imageUrlToStyle{get; set;}
    public Map<String, String> imageUrlToDesc{get; set;}
    public String UnitId {get; set;}
    public String projectName {get; set;}
    public String unitTitleInventory {get; set;}
    public String unitTitle {get; set;} 
    public String unitModel {get; set;}
    public String unitBuilding {get; set;}
    public String projectHandover {get; set;}
    public Decimal numberBedrooms {get; set;}
    public Decimal numberBathrooms {get; set;}
    public String balcony {get; set;}
    public String unitType {get; set;}
    public String unitTotalArea {get; set;}
    public String unitTotalAreaSQM {get; set;}
    public String unitLivingSpace {get; set;}
    public String unitAdditionalArea {get; set;}
    public String unitFloorText {get; set;}
    public String unitFloor {get; set;}
    public String unitView {get; set;} 
    public Boolean unitPool {get; set;}
    public Boolean unitMaidsRoom {get; set;}
    public String unitPanoramaLink {get; set;}
    public String unitCost {get; set;}
    public String unitCostCHF {get; set;}
    public String unitCostAED {get; set;}
    public String unitCostUSD {get; set;}
    public String unitCostUSDNumber {get; set;}
    public String unitAmountUSD {get; set;}
    public String unitAmountEUR {get; set;}
    public String unitAmountRUB {get; set;}
    public String unitAmountGBP {get; set;}
    public String unitSecondaryCurrency {get; set;}
    public String completionDate {get; set;}
    public Boolean IsOnePic {get; set;}
    public Boolean lessPayment {get; set;}
    public String selectedCurrency {get; set;}

    // Builder class
    public class UnitWrapperBuilder {
        private UnitWrapper wrapper;
        private Decimal numericFloor;
        
        public UnitWrapperBuilder() {
            wrapper = new UnitWrapper();
        }
        
        public UnitWrapperBuilder setBasicInfo(String uId, String pName, String uTitle, String uTitleInvent) {
            wrapper.UnitId = uId;
            wrapper.projectName = pName;
            wrapper.unitTitle = uTitle;
            wrapper.unitTitleInventory = uTitleInvent;
            return this;
        }
        
        public UnitWrapperBuilder setUnitDetails(String uModel, String uBuilding, String pHandover, 
            Decimal uBedrooms, Decimal uBathrooms, String uBalcony, String uType, String uArea, String uAreaSQM, String uSpace, 
            String uAdditionalArea, Decimal uFloor, String uView, Boolean uPool, Boolean uMaidsRoom) {
            wrapper.unitModel = uModel;
            wrapper.unitBuilding = uBuilding;
            wrapper.projectHandover = pHandover;
            wrapper.numberBedrooms = uBedrooms;
            wrapper.numberBathrooms = uBathrooms;
            wrapper.balcony = uBalcony;
            wrapper.unitType = uType;
            wrapper.unitTotalArea = uArea;
            wrapper.unitTotalAreaSQM = uAreaSQM;
            wrapper.unitLivingSpace = uSpace;
            wrapper.unitAdditionalArea = uAdditionalArea;
            wrapper.unitFloorText = getFloorText(uFloor);
            wrapper.unitFloor = String.valueOf(uFloor);
            wrapper.unitView = uView;
            wrapper.unitPool = uPool;
            wrapper.unitMaidsRoom = uMaidsRoom;
            return this;
        }
        
        public UnitWrapperBuilder setFinancialInfo(String uCost, String uCostCHF, String uCostAED, String uCostUSD, String uCostUSDNumber, String uAmountUSD, String uAmountEUR, 
            String uAmountRUB, String uAmountGBP, String uSecondaryCurrency, String cDate) {
            wrapper.unitCost = uCost;
            wrapper.unitCostCHF = uCostCHF;
            wrapper.unitCostAED = uCostAED;
            wrapper.unitCostUSD = uCostUSD;
            wrapper.unitCostUSDNumber = uCostUSDNumber;
            wrapper.unitAmountUSD = uAmountUSD;
            wrapper.unitAmountEUR = uAmountEUR;
            wrapper.unitAmountRUB = uAmountRUB;
            wrapper.unitAmountGBP = uAmountGBP;
            wrapper.unitSecondaryCurrency = uSecondaryCurrency;
            wrapper.completionDate = cDate;
            return this;
        }
        
        public UnitWrapperBuilder setPaymentPlans(List<PaymentPlanWrapper> fpwrap, List<PaymentPlanWrapper> rpwrap) {
            wrapper.fpwrapper = fpwrap;
            wrapper.rpwrapper = rpwrap;
            return this;
        }
        
        public UnitWrapperBuilder setImageInfo(Set<String> imgUrlToStyleKeySet, 
            Map<String, String> imgUrlToStyle, Map<String, String> imgUrlToDesc) {
            wrapper.imageUrlToStyleKeySet = imgUrlToStyleKeySet;
            wrapper.imageUrlToStyle = imgUrlToStyle;
            wrapper.imageUrlToDesc = imgUrlToDesc;
            return this;
        }
        
        public UnitWrapperBuilder setAdditionalInfo(String uPanoramaLink, Boolean onePic, 
            Boolean lsPayment, String sCurrency) {
            wrapper.unitPanoramaLink = uPanoramaLink;
            wrapper.IsOnePic = onePic;
            wrapper.lessPayment = lsPayment;
            wrapper.selectedCurrency = sCurrency;
            return this;
        }

        private String getFloorText(Decimal floorValue) {
            if (floorValue == 9) {
                return 'Ground';
            } else if (floorValue == 1) {
                return 'First';
            } else if (floorValue == 2) {
                return 'Second';
            } else if (floorValue == 3) {
                return 'Third';
            } else if (floorValue == 91) {
                return 'Ground / First';
            } else if (floorValue == 12) {
                return 'First / Second';
            } else if (floorValue == 23) {
                return 'Second / Third';
            } else if (floorValue == 34) {
                return 'Third / Fourth';
            } else if (floorValue == 123) {
                return 'First / Second / Third';
            } else {
                return '';
            }
        }
        
        public UnitWrapper build() {
            return wrapper;
        }
    }
    
    // Private constructor
    private UnitWrapper() {}
    
    // Static method to create builder
    public static UnitWrapperBuilder builder() {
        return new UnitWrapperBuilder();
    }
}