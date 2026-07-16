public class AmountInWords {
    private static String[] unitsTensTeens = new String[] {'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'};
    private static String[] tens = new String[] {'', 'Ten', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
    public static String convertNumberToText(Decimal n) {
        if (n == null) {
            return '';
        }
        Integer integerValue = n.intValue();    
        if (integerValue == 0) {
            return 'Zero';
        }
        String textRepresentation = '';
        if (integerValue >= 1000000) {
            textRepresentation += convertNumberToText(integerValue / 1000000) + ' Million, ';
            integerValue = math.mod(integerValue,1000000);
        }
        if (integerValue >= 1000) {
            textRepresentation += convertNumberToText(integerValue / 1000) + ' Thousand, ';
            integerValue = math.mod(integerValue,1000);
        }
        if (integerValue >= 100) {
            textRepresentation += unitsTensTeens[integerValue / 100] + ' Hundred ';
            integerValue = math.mod(integerValue,100);
        }
        if (integerValue >= 20) {
            textRepresentation += tens[integerValue / 10] + ' ';
            integerValue = math.mod(integerValue,10);
        }
        if (integerValue > 0) {
            textRepresentation += unitsTensTeens[integerValue];
        }
        return textRepresentation.trim();
    }
    // Invocable method for Salesforce Flows
    /*@InvocableMethod(label='Convert Number to Text' description='Converts a given number to its textual representation.')
    public static List<String> convertNumberToFlow(List<Decimal> numbers) {
        List<String> textRepresentations = new List<String>();
        for(Decimal n : numbers) {
            textRepresentations.add(convertNumberToText(n));
        }
        return textRepresentations;
    }*/
}