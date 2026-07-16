import { LightningElement, wire, api } from 'lwc';

import jsPDF from '@salesforce/resourceUrl/jsPDF';
import fontScript from '@salesforce/resourceUrl/fontScript';
import MiraDocLogo from '@salesforce/resourceUrl/MiraDocLogo';
import DOMPurify from '@salesforce/resourceUrl/DOMPurify';
import jsPDFautoTable from '@salesforce/resourceUrl/jsPDFautoTable';
import pdfLib from '@salesforce/resourceUrl/pdfLib';
import { loadScript } from 'lightning/platformResourceLoader';
import {CurrentPageReference} from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getData from '@salesforce/apex/BookingOfferPDFController.getData';

export default class BookingOfferPdf extends LightningElement {
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.attributes.recordId;
        }
    }
    data;
    dataLoaded=false;
    jsPdfInitialized=false;
    miraLogo = MiraDocLogo;
    get disableButton(){
        return !this.dataLoaded;
    }
    renderedCallback(){
        if (this.jsPdfInitialized) {
            return;
        }
        this.jsPdfInitialized = true;
        Promise.all([
            loadScript(this, jsPDF + '/jsPDF-master/dist/jspdf.umd.min.js').then(() => {
                console.log("JS loaded");
                loadScript(this, fontScript).then(() => {
                    console.log("second script loaded");

                    loadScript(this, DOMPurify + '/DOMPurify-main/dist/purify.min.js').then(() => {
                        console.log("Third script loaded");
                        loadScript(this, jsPDFautoTable + '/jsPDF-AutoTable-master/dist/jspdf.plugin.autotable.min.js').then(() => {
                            console.log("Fourth script loaded");
                            loadScript(this, pdfLib).then(() => {
                                console.log("Fifth script loaded");
                                this.dataLoaded = true;
                            }).catch(error => {
                                console.error("Error loading fourth script: " + error);
                            });
                        }).catch(error => {
                            console.error("Error loading fourth script: " + error);
                        });
                    }).catch(error => {
                        console.error("Error loading third script: " + error);
                    });
                }).catch(error => {
                    console.error("Error loading second script: " + error);
                });
            }).catch(error => {
                console.error("Error loading first script: " + error);
            })
        ]);
        
    }

    async generatePDF(){
        const { jsPDF } = window.jspdf;
            const { PDFDocument } = window.PDFLib;
            const doc = new jsPDF();
            doc.setTextColor('#2A324B'); 
            var logoImgData = 'data:image/png;base64,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';

            doc.setFontSize(10);
            doc.setFont("Amiri-Regular");

            let registrationFeesArabic = '';
            if (this.data.opportunity.Registration_Fees__c === 'Fully paid by the Purchaser'){
                registrationFeesArabic = 'مدفوعة بالكامل من قبل المشتري';
            } else if (this.data.opportunity.Registration_Fees__c === 'Fully paid by the Seller'){
                registrationFeesArabic = 'مدفوعة بالكامل من قبل البائع';
            } else if (this.data.opportunity.Registration_Fees__c === '50% payable by Purchaser, 50% payable by Seller, Purchaser pays all administration fees'){
                registrationFeesArabic = '٥٠٪؜ تدفع من قبل المشترى ، و ٥٠٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية'
            }
            
            let contractDetailsSectionArabic = this.data.date+' :التاریخ\n'+' البائع: '+'ام اي ار ايه للتطوير ش.ذ.م.م\nالمشروع: '+this.data.opportunity.Unit__r.Project__r.Project_Name_Arabic__c+'\n'+this.data.opportunity.Unit__r.Title_Formula__c+' :الوحدة العقاریة\n'+this.data.opportunity.Unit__r.Building__c+' :البنایة / المرحلة\n'+this.data.opportunity.Unit__r.Name+' :رقم الوحدة\n'+this.data.opportunity.Unit__r.Number_of_Bedrooms__c+' :عدد الغرف\nsq. ft. '+this.addCommasToNumber(this.data.opportunity.Unit__r.Total_Area__c)+' :المساحة الإجمالیة\n '+
            'ثمن الشراء: '+this.addCommasToNumber(this.data.opportunity.Unit__r.Cost_AED__c)+ 'درھم إماراتي \n'+
            'ضریبة القیمة المضافة: % 0.00\n'+
            'ثمن الشراء شامل لضريبة القيمة المضافة: '+this.addCommasToNumber(this.data.opportunity.Unit__r.Cost_AED__c)+'درھم إماراتي \n'+
            'العربون: '+this.addCommasToNumber(this.data.firstIntallment)+'درھم إماراتي '+'\nرسوم التسجيل: '+registrationFeesArabic;

            let contractDetailsSection = 'Date: '+this.data.date+'\nVendor: M I R A Developments LLC\nProject: '+this.data.opportunity.Unit__r.Project__r.Name+'\nProperty: '+this.data.opportunity.Unit__r.Title_Formula__c+'\nBuilding / Phase: '+this.data.opportunity.Unit__r.Building__c+'\nUnit: '+this.data.opportunity.Unit__r.Name+'\nNo. of Bedrooms: '+this.data.opportunity.Unit__r.Number_of_Bedrooms__c+'\nTotal Area: sq. ft. '+this.addCommasToNumber(this.data.opportunity.Unit__r.Total_Area__c)+'\nPurchase Price: AED '+this.addCommasToNumber(this.data.opportunity.Unit__r.Cost_AED__c)+'\nVAT: 0.00%\nPurchase Price Incl. of VAT: AED '+this.addCommasToNumber(this.data.opportunity.Unit__r.Cost_AED__c)+'\nDeposit: AED '+this.addCommasToNumber(this.data.firstIntallment)+'\nRegistration fees: '+(this.data.opportunity.Registration_Fees__c != undefined ? this.data.opportunity.Registration_Fees__c : '');

            doc.autoTable({
                theme: 'plain',
                startY: 20,
                margin: 5,
                color: [42, 50, 75],
                styles: { lineColor: '#2A324B', lineWidth: 0, cellPadding: 2 },
                columnStyles: { textColor: [42, 50, 75], eng: { halign: 'left', font: 'Amiri-Regular' }, arab: { halign: 'right', font: 'Amiri-Regular', cellWidth:120 } },
                body: [
                  { eng: contractDetailsSection, arab: contractDetailsSectionArabic}
                ],
                columns: [
                  { header: '', dataKey: 'eng' },
                  { header: '', dataKey: 'arab' },
                ],
            });


            let personalDetailsSection = 
            'Name: '+this.data.opportunity.Account.Name+'\n'+
            'Ownership Share: '+this.data.opportunity.Ownership_Share_of_the_Main_Purchaser__c+'%\n'+
            'License No. (For legal entities): '+this.data.licenseNumberValue+'\n'+
            'Country of Incorporation: '+this.data.incorporationCountry+'\n'+
            'Nationality: '+this.data.opportunity.Account.Nationality__c+'\n'+
            'Passport No: '+this.data.opportunity.Account.Passport_No__c+'\n'+
            'P.O. Box / Postal Code: '+this.data.opportunity.Account.BillingPostalCode+'\n'+
            'City: '+this.data.opportunity.Account.BillingCity+'    '+
            'Country: '+this.data.opportunity.Account.BillingCountry+'\n'+
            'Address: '+this.data.opportunity.Account.BillingStreet+'\n\n'+
            'Mobile: '+this.data.opportunity.Account.PersonMobilePhone+'\n'+
            'Telephone: '+this.data.opportunity.Account.Phone+'\n'+
            'Email: '+this.data.opportunity.Account.PersonEmail;
            personalDetailsSection = personalDetailsSection.replaceAll("undefined", '')


            let incorporationLine;
            if(this.data.incorporationCountryArabic === 'N/A'){
                incorporationLine = this.data.incorporationCountryArabic + ' :البلد الذي تأسست فيه';
            } else {
                incorporationLine = 'البلد الذي تأسست فيه: '+this.data.incorporationCountryArabic;
            }

            let personalDetailsSectionArabic =
            'الاسم: '+ (this.data.opportunity.Account.IsPersonAccount ? (this.data.opportunity.Account.Contact_First_Name_Arabic__pc+' '+this.data.opportunity.Account.Contact_Middle_Name_Arabic__pc+' '+this.data.opportunity.Account.Contact_Last_Name_Arabic__pc):this.data.opportunity.Account.Account_Name_Arabic__c)+'\n'+
            this.data.opportunity.Ownership_Share_of_the_Main_Purchaser__c+'%'+' :حصة الملكية'+'\n'+
            this.data.licenseNumberValue+' :(للشركات) رقم الرخصة'+'\n'+
            incorporationLine+'\n'+
            'الجنسية: '+this.data.opportunity.Account.Nationality_Arabic__c+'\n'+
            this.data.opportunity.Account.Passport_No__c+' :رقم جواز السفر'+'\n'+
            'الرمز البريدي / ص.ب: '+this.data.opportunity.Account.Postal_Code_Arabic__c+'\n'+
            'المدینة: '+this.data.opportunity.Account.City_Arabic__c+'    '+
            'البلد: '+this.data.opportunity.Account.Country_Arabic__c+'\n'+
            'العنوان: '+this.data.opportunity.Account.Address__c+'\n\n'+
            this.data.opportunity.Account.PersonMobilePhone+' :الهاتف المتحرك'+'\n'+
            this.data.opportunity.Account.Phone+' :الھاتف'+'\n'+
            this.data.opportunity.Account.PersonEmail+' :البريد الإلكتروني';
            personalDetailsSectionArabic = personalDetailsSectionArabic.replaceAll("undefined", '')

            let addressSection=
            'Address: '+this.data.opportunity.Account.BillingStreet+'\n'+
            'P.O. Box / Postal Code: '+this.data.opportunity.Account.BillingPostalCode+'\n'+
            'City: '+this.data.opportunity.Account.BillingCity+'    '+
            'Country: '+this.data.opportunity.Account.BillingCountry+'\n'+
            'Mobile: '+this.data.opportunity.Account.PersonMobilePhone;
            addressSection = addressSection.replaceAll("undefined", '');

            let addressSectionArabic=
            // 'عنوان تسليم الاتفاقية البيع والشراء: سيتم استخدام العنوان التالي فقط لتسليم اتفاقية البيع والشراء الخاصة بالبائع. وسيتم إرسال / تسليم جميع المراسلات والإخطارات والإشعارات الأخرى إلى العنوان الأساسي المذكور أعلاه.\n\n'+
            'العنوان: '+this.data.opportunity.Account.Address__c+'\n'+
            'الرمز البريدي / ص.ب: '+this.data.opportunity.Account.Postal_Code_Arabic__c+'\n'+
            'المدینة: '+this.data.opportunity.Account.City_Arabic__c+'    '+
            'البلد: '+this.data.opportunity.Account.Country_Arabic__c+'\n'+
            this.data.opportunity.Account.PersonMobilePhone+' :الهاتف المتحرك';
            addressSectionArabic = addressSectionArabic.replaceAll("undefined", '');

            let customerDueD = 'Date of Birth: '+this.data.opportunity.Account.PersonBirthdate+'\nPlace of Birth: '+this.data.opportunity.Account.Place_of_Birth__pc+'\nOccupation/ Name of Employer: '+this.data.opportunity.Account.Occupation__pc+'\nSource of Funds: \n '+this.data.opportunity.Account.Source_of_Funds__pc+ (this.data.opportunity.Account.Source_of_Funds__pc == 'Other' ? ': '+this.data.opportunity.Account.Source_of_Funds_Other__pc : '')+
            '\nAre you a politically exposed person, or a close family member or associate of one?\n '+(this.data.opportunity.Account.Politically_Exposed__pc == 'Yes, please specify' ? 'Yes, '+this.data.opportunity.Account.Politically_Exposed_Person_Text__pc:'No')+
            '\nEstimated duration of holding the property:\n '+this.data.opportunity.Account.Estimated_duration__pc+'\n'+
            'Payment methods:\n '+(this.data.opportunity.Account.Payment_methods__pc != undefined ? this.data.opportunity.Account.Payment_methods__pc.replaceAll(";", ', '):'')+(this.data.opportunity.Account.Payment_methods__pc != undefined ?(this.data.opportunity.Account.Payment_methods__pc.includes('Other')?': '+this.data.opportunity.Account.Payment_Methods_Other__pc:''):'')+
            '\nCurrency:\n '+this.data.opportunity.Account.Currency__pc+(this.data.opportunity.Account.Currency__pc == 'Others' ? ': '+this.data.opportunity.Account.Currency_Other__pc : '');
            customerDueD = customerDueD.replaceAll("undefined", '');

            let sourceOfFundsArabic = [{'Salary':'راتب'},{'Investments':'استثمارات'},{'Business Income':'دخل من الأعمال'},{'Loans':'قروض'},{'Other':'آخر'}];
            let durationArabic = [{'0-1 Year':'0-1 سنة'},{'1-3 Years':'1-3  سنوات'},{'3-5 Years':'3-5  سنوات'},{'More than 5 Years':'أكثر من 5 سنوات'}];
            let paymentArabic = [{'Cash':'نقدًا'},{'Cheques':'شيكات'},{'Bank Transfer':'تحويل بنكي'},{'Others':'آخر'}];
            let paymentMethodsTranslatedString = '';
            let splitValues = this.data.opportunity.Account.Payment_methods__pc != undefined ? this.data.opportunity.Account.Payment_methods__pc.split(';') : [];
            let translatedValues = splitValues.map(function(value) {
              let arabicLabel = '';
              for (let i = 0; i < paymentArabic.length; i++) {
                let mapping = paymentArabic[i];
                for (let key in mapping) {
                  if (mapping.hasOwnProperty(key) && key === value.trim()) {
                    arabicLabel = mapping[key];
                  }
                }
              }
              return arabicLabel || value.trim();
            });
            paymentMethodsTranslatedString = translatedValues.join(', ');

            let customerDueDArabic = ' تاريخ الميلاد: '+this.data.opportunity.Account.Date_of_Birth_Arabic__c+'\n  مكان الميلاد: '+this.data.opportunity.Account.Place_of_Birth_Arabic__pc+'\nالمهنة /صاحب العمل: '+this.data.opportunity.Account.Occupation_Arabic__pc+'\n:مصدر الأموال\n '+
            this.findArabicLabelByEnglishValue(this.data.opportunity.Account.Source_of_Funds__pc,sourceOfFundsArabic)+(this.data.opportunity.Account.Source_of_Funds__pc == 'Other' ? ': '+this.data.opportunity.Account.Source_of_Funds_Other_Arabic__pc : '')+' '+
            '\nهل انت من اصحاب النفوذ السياسي او احد افراد عائلتك المقربة او معارفك؟\n '+(this.data.opportunity.Account.Politically_Exposed__pc == 'Yes, please specify' ? 'نعم, '+this.data.opportunity.Account.Politically_Exposed_Person_Text_Arabic__pc:'لا')+' '+
            '\n\n:المدة المقدرة لامتلاك العقار\n '+this.findArabicLabelByEnglishValue(this.data.opportunity.Account.Estimated_duration__pc,durationArabic)+' '+'\n'+
            ':طرق الدفع\n '+paymentMethodsTranslatedString+(this.data.opportunity.Account.Payment_methods__pc != undefined ? (this.data.opportunity.Account.Payment_methods__pc.includes('Other')?': '+this.data.opportunity.Account.Payment_Methods_Other_Arabic__pc:''):'')+' '+
            '\n:العملة\n '+(this.data.opportunity.Account.Currency__pc == 'AED' ? '(AED) درهم إماراتي' : '')+(this.data.opportunity.Account.Currency__pc == 'Others' ? 'آخر: '+this.data.opportunity.Account.Currency_Other_Arabic__pc : '')+' ';
            customerDueDArabic = customerDueDArabic.replaceAll("undefined", '');

            let purchasersRows = [
                { eng: 'Purchaser 1 Information', arab: '1 معلومات المشتري رقم '},
                { eng: personalDetailsSection, arab: personalDetailsSectionArabic},
                { eng: 'Customer Due Diligence – Purchaser 1', arab: 'التدقيق اللازم للعميل - المشتري رقم 1'},
                { eng: customerDueD, arab: customerDueDArabic},
                { eng: 'Note: The above address/contact details are considered the Purchaser’s primary address and chosen domicile and shall be printed on the Vendor’s Sales and Purchase Agreement and used for all communications /correspondences with the Purchaser.', 
                arab: 'ملاحظة: إن العنوان/بيانات الاتصال أعلاه تعتبر العنوان الأساسي والمختار للمشتري\n وسيتم طباعتها على اتفاقية البيع والشراء الخاصة بالبائع واعتمادها في جميع\n الاتصالات/المراسلات مع المشتري'},
                { eng: 'Note: Customer Due Diligence is required by the Vendor under applicable laws. ', 
                arab: '.ملاحظة: يتطلب التدقيق اللازم للعميل من قبل البائع بموجب القوانين المطبقة'},
                { eng: 'Delivery Address for the Sales and Purchase Agreement: the following address will be used solely for the delivery of the Vendor’s Sales and Purchase Agreement. All other communications, correspondences, notifications and notices shall be dispatched/delivered to the primary address above.', 
                arab: 'عنوان تسليم الاتفاقية البيع والشراء: سيتم استخدام العنوان التالي فقط لتسليم\n اتفاقية البيع والشراء الخاصة بالبائع. وسيتم إرسال / تسليم جميع المراسلات\n.والإخطارات والإشعارات الأخرى إلى العنوان الأساسي المذكور أعلاه'},
                {eng: addressSection, arab: addressSectionArabic}
              ];
            this.data.jointOwners.sort((a, b) => {
                const orderA = this.data.jointOwnersOrder[a.Id];
                const orderB = this.data.jointOwnersOrder[b.Id];
                
                const orderANum = parseInt(orderA);
                const orderBNum = parseInt(orderB);
                
                if (orderANum < orderBNum) {
                    return -1;
                } else if (orderANum > orderBNum) {
                    return 1;
                } else {
                    return 0;
                }
            });
            for(let i = 0; i < this.data.jointOwners.length; i++){
                let number = i+2;
                purchasersRows.push({ eng: 'Purchaser '+number+' Information', arab: number+ ' معلومات المشتري رقم '});
                let extraPersonalDetailsSection = 
                    'Name: '+this.data.jointOwners[i].Name+'\n'+
                    'Ownership Share: '+this.data.jointOwnersOwnership[this.data.jointOwners[i].Id]+'%\n'+
                    'License No. (For legal entities): '+this.data.jointOwnersLicenseValues[this.data.jointOwners[i].Id]+'\n'+
                    'Country of Incorporation: '+this.data.jointOwnersIncorporationValues[this.data.jointOwners[i].Id]+'\n'+
                    'Nationality: '+this.data.jointOwners[i].Nationality__c+'\n'+
                    'Passport No: '+this.data.jointOwners[i].Passport_No__c+'\n'+
                    'P.O. Box / Postal Code: '+this.data.jointOwners[i].BillingPostalCode+'\n'+
                    'City: '+this.data.jointOwners[i].BillingCity+'    '+
                    'Country: '+this.data.jointOwners[i].BillingCountry+'\n'+
                    'Address: '+this.data.jointOwners[i].BillingStreet+'\n\n'+
                    'Mobile: '+this.data.jointOwners[i].PersonMobilePhone+'\n'+
                    'Telephone: '+this.data.jointOwners[i].Phone+'\n'+
                    'Email: '+this.data.jointOwners[i].PersonEmail;
                    extraPersonalDetailsSection = extraPersonalDetailsSection.replaceAll("undefined", '');

                let incorporationLine;
                if(this.data.jointOwnersIncorporationValuesArabic[this.data.jointOwners[i].Id] === 'N/A'){
                    incorporationLine = this.data.jointOwnersIncorporationValuesArabic[this.data.jointOwners[i].Id] + ' :البلد الذي تأسست فيه';
                } else {
                    incorporationLine = 'البلد الذي تأسست فيه: '+this.data.jointOwnersIncorporationValuesArabic[this.data.jointOwners[i].Id];
                }
                let extraPersonalDetailsSectionArabic =
                    'الاسم: '+ (this.data.jointOwners[i].IsPersonAccount ? (this.data.jointOwners[i].Contact_First_Name_Arabic__pc+' '+this.data.jointOwners[i].Contact_Middle_Name_Arabic__pc+' '+this.data.jointOwners[i].Contact_Last_Name_Arabic__pc):this.data.jointOwners[i].Account_Name_Arabic__c)+'\n'+
                    this.data.jointOwnersOwnership[this.data.jointOwners[i].Id]+'%'+' :حصة الملكية'+'\n'+
                    this.data.jointOwnersLicenseValues[this.data.jointOwners[i].Id]+' :(للشركات) رقم الرخصة'+'\n'+
                    incorporationLine+'\n'+
                    'الجنسية: '+this.data.jointOwners[i].Nationality_Arabic__c+'\n'+
                    this.data.jointOwners[i].Passport_No__c+' :رقم جواز السفر'+'\n'+
                    'الرمز البريدي / ص.ب: '+this.data.jointOwners[i].Postal_Code_Arabic__c+'\n'+
                    'المدینة: '+this.data.jointOwners[i].City_Arabic__c+'    '+
                    'البلد: '+this.data.jointOwners[i].Country_Arabic__c+'\n'+
                    'العنوان: '+this.data.jointOwners[i].Address__c+'\n\n'+
                    this.data.jointOwners[i].PersonMobilePhone+' :الهاتف المتحرك'+'\n'+
                    this.data.jointOwners[i].Phone+' :الھاتف'+'\n'+
                    this.data.jointOwners[i].PersonEmail+' :البريد الإلكتروني';
                    extraPersonalDetailsSectionArabic = extraPersonalDetailsSectionArabic.replaceAll("undefined", '');

                let customerDueD = 'Date of Birth: '+this.data.jointOwners[i].PersonBirthdate+'\nPlace of Birth: '+this.data.jointOwners[i].Place_of_Birth__pc+'\nOccupation/ Name of Employer: '+this.data.jointOwners[i].Occupation__pc+'\nSource of Funds: \n '+this.data.jointOwners[i].Source_of_Funds__pc+ (this.data.jointOwners[i].Source_of_Funds__pc == 'Other' ? ': '+this.data.jointOwners[i].Source_of_Funds_Other__pc : '')+
                '\nAre you a politically exposed person, or a close family member or associate of one?\n '+(this.data.jointOwners[i].Politically_Exposed__pc == 'Yes, please specify' ? 'Yes, '+this.data.jointOwners[i].Politically_Exposed_Person_Text__pc:'No')+
                '\nEstimated duration of holding the property:\n '+this.data.jointOwners[i].Estimated_duration__pc+'\n'+
                'Payment methods:\n '+(this.data.jointOwners[i].Payment_methods__pc != undefined ? this.data.jointOwners[i].Payment_methods__pc.replaceAll(";", ', '):'')+(this.data.jointOwners[i].Payment_methods__pc != undefined ?(this.data.jointOwners[i].Payment_methods__pc.includes('Other')?': '+this.data.jointOwners[i].Payment_Methods_Other__pc:''):'')+
                '\nCurrency:\n '+this.data.jointOwners[i].Currency__pc+(this.data.jointOwners[i].Currency__pc == 'Others' ? ': '+this.data.jointOwners[i].Currency_Other__pc : '');
                customerDueD = customerDueD.replaceAll("undefined", '');

                let paymentMethodsTranslatedString = '';
                if(this.data.jointOwners[i].Payment_methods__pc != undefined){

                    let splitValues = this.data.jointOwners[i].Payment_methods__pc.split(';');
                    let translatedValues = splitValues.map(function(value) {
                      let arabicLabel = '';
                      for (let i = 0; i < paymentArabic.length; i++) {
                        let mapping = paymentArabic[i];
                        for (let key in mapping) {
                          if (mapping.hasOwnProperty(key) && key === value.trim()) {
                            arabicLabel = mapping[key];
                          }
                        }
                      }
                      return arabicLabel || value.trim();
                    });
                    paymentMethodsTranslatedString = translatedValues.join(', ');
                }
    
                let customerDueDArabic = ' تاريخ الميلاد: '+this.data.jointOwners[i].Date_of_Birth_Arabic__c+'\n  مكان الميلاد: '+this.data.jointOwners[i].Place_of_Birth_Arabic__pc+'\nالمهنة /صاحب العمل:'+this.data.jointOwners[i].Occupation_Arabic__pc+'\n:مصدر الأموال\n '+
                this.findArabicLabelByEnglishValue(this.data.jointOwners[i].Source_of_Funds__pc,sourceOfFundsArabic)+(this.data.jointOwners[i].Source_of_Funds__pc == 'Other' ? ': '+this.data.jointOwners[i].Source_of_Funds_Other_Arabic__pc : '')+' '+
                '\nهل انت من اصحاب النفوذ السياسي او احد افراد عائلتك المقربة او معارفك؟\n '+(this.data.jointOwners[i].Politically_Exposed__pc == 'Yes, please specify' ? 'نعم, '+this.data.jointOwners[i].Politically_Exposed_Person_Text_Arabic__pc:'لا')+' '+
                '\n\n:المدة المقدرة لامتلاك العقار\n '+this.findArabicLabelByEnglishValue(this.data.jointOwners[i].Estimated_duration__pc,durationArabic)+' '+'\n'+
                ':طرق الدفع\n '+paymentMethodsTranslatedString+(this.data.jointOwners[i].Payment_methods__pc != undefined ? (this.data.jointOwners[i].Payment_methods__pc.includes('Other')?': '+this.data.jointOwners[i].Payment_Methods_Other_Arabic__pc:''):'')+' '+
                '\n:العملة\n '+(this.data.jointOwners[i].Currency__pc == 'AED' ? '(AED) درهم إماراتي' : '')+(this.data.jointOwners[i].Currency__pc == 'Others' ? 'آخر: '+this.data.jointOwners[i].Currency_Other_Arabic__pc : '')+' ';
                customerDueDArabic = customerDueDArabic.replaceAll("undefined", '');
                purchasersRows.push({ eng: extraPersonalDetailsSection, arab: extraPersonalDetailsSectionArabic});
                purchasersRows.push({ eng: 'Customer Due Diligence – Purchaser '+ number, arab: number+'التدقيق اللازم للعميل - المشتري رقم '});
                purchasersRows.push({ eng: customerDueD, arab: customerDueDArabic});

            }
            doc.autoTable({
                theme: 'plain',
                startY: 85,
                margin: {top: 20, right: 5, bottom: 20, left: 5},
                color: [42, 50, 75],
                styles: { lineColor: '#2A324B', lineWidth: 0.2, cellPadding: 2 },
                columnStyles: { textColor: [42, 50, 75], eng: { halign: 'left', font: 'Amiri-Regular', cellWidth: 100 }, arab: { halign: 'right', font: 'Amiri-Regular', cellWidth: 100,overflow: 'hidden' } },
                body: purchasersRows,
                columns: [
                  { header: '', dataKey: 'eng' },
                  { header: '', dataKey: 'arab' },
                ],
            });
            let termsStartY = 50;
            if(this.data.jointOwners.length == 1){
                termsStartY = 180;
            } else if (this.data.jointOwners.length == 2){
                termsStartY = 60;
            } else if (this.data.jointOwners.length == 3){
                termsStartY = 190;
            } else if (this.data.jointOwners.length == 4){
                termsStartY = 70;
            } else if (this.data.jointOwners.length == 5){
                termsStartY = 200;
            }
            doc.autoTable({
                theme: 'plain',
                startY: termsStartY,
                margin: 5,
                color: [42, 50, 75],
                styles: { lineColor: '#2A324B', cellPadding: 2 },
                columnStyles: { textColor: [42, 50, 75], 
                    eng: { halign: 'left', font: 'Amiri-Regular', cellWidth: 95, cellPadding: {top: 0, right: 2, bottom: 2, left: 0},overflow: 'linebreak'}, 
                    arab: { halign: 'right', font: 'Amiri-Regular', cellWidth: 95, cellPadding: {top: 0, right: 0, bottom: 2, left: 2},overflow: 'hidden'},
                    num : { halign: 'right', font: 'Amiri-Regular',cellWidth: 5, cellPadding: {top: 0, right: 2, bottom: 0, left: 0},overflow: 'linebreak'},
                    numArab : { halign: 'right', font: 'Amiri-Regular',cellWidth: 5, cellPadding: {top: 0, right: 0, bottom: 0, left: 2},overflow: 'linebreak'} 
                },
                body: [
                  { num: '',numArab: '', eng: 'Terms & Conditions ', arab: 'الشروط والاحكام'},
                  { num: '1.',numArab: '.1', eng: 'This unconditional and irrevocable Offer to Purchase the Property is made by the abovementioned purchaser(s) (the “Purchaser”) to the Vendor and is binding on the Purchaser. The sale of the Property is subject to approval by the Vendor as per Clause (3) below.', 
                  arab: 'قدم عرض شراء الوحدة العقاریة ھذا، وھو غیر مشروط وغیر قابل للنقض، من\n قبل المشتري/المشتریین المذكور/المذكورین أعلاه )المشتري( إلى البائع، وھو\n ملزم على المشتري. إن بیع الوحدة العقاریة یخضع لموافقة البائع وفقاً\n للبند )3( أدناه.'},
                  { num: '2.',numArab: '.2', eng: 'The Purchaser unconditionally, irrevocably, and finally agrees to purchase the Property from the Vendor at the above Purchase Price, in accordance with the following Payment Schedule', 
                  arab: 'یوافق المشتري ، دون قید أو شرط وبشكل نھائي غیر قابل للرجوع عنھ، على\n شراء الوحدة العقاریة من البائع مقابل ثمن الشراء المذكور أعلاه، ووفقا\n لجدول الدفع التالي'}
                ],
                columns: [
                    { header: '', dataKey: 'num' },
                    { header: '', dataKey: 'eng' },
                    { header: '', dataKey: 'arab' },
                    { header: '', dataKey: 'numArab' }
                ],
                didDrawCell: (data) => {
                    if (data.section === 'body') {
                        if(data.row.index === 10){

                            doc.autoTable({
                                theme: 'plain',
                                startY: data.cell.y,
                                tableWidth: 95,
                                margin: {top: 0, right: 0, bottom: 0, left: 105},
                                styles: { lineColor: '#2A324B', lineWidth: 0.5, cellPadding: 0 },
                                columns: [
                                    { header: '', dataKey: 'txt' }
                                ],
                                body: [
                                    { txt: 'test'}
                                ]
    
                            })
                        }
                    }
                }
            });
            doc.addPage();

            
            let paymentTableData = [];
            for(let i = 0; i < this.data.paymentPlans.length; i++){
                paymentTableData.push({
                    no:this.data.paymentPlans[i].numberOfPlan,
                    date:this.data.paymentPlans[i].paymentDate,
                    milestone:this.data.paymentPlans[i].milestone,
                    idk:'',
                    perc:this.addCommasToNumber(this.data.paymentPlans[i].percent)+'%',
                    amount:this.addCommasToNumber(this.data.paymentPlans[i].amount),
                    vat:'0',
                    wholeAmount:this.addCommasToNumber(this.data.paymentPlans[i].amount)
                })
            }
            doc.autoTable({
                theme: 'plain',
                startY: 20,
                margin: {top: 20, right: 5, bottom: 20, left: 5},
                color: [42, 50, 75],
                styles: { lineColor: '#2A324B', lineWidth: 0.2, cellPadding: 1 },
                columnStyles: { textColor: [42, 50, 75], no: { halign: 'center', font: 'Amiri-Regular', cellWidth: 15},
                    date: { halign: 'center', font: 'Amiri-Regular'}, milestone: { halign: 'center', font: 'Amiri-Regular'},
                    idk: { halign: 'center', font: 'Amiri-Regular', cellWidth: 25}, perc: { halign: 'center', font: 'Amiri-Regular'},
                    amount: { halign: 'center', font: 'Amiri-Regular'}, vat: { halign: 'center', font: 'Amiri-Regular'},
                    wholeAmount: { halign: 'center', font: 'Amiri-Regular'} },
                headStyles: {font: 'Amiri-Regular', halign: 'center', fontSize: 10},
                body: paymentTableData,
                columns: [
                  { header: 'Sr. No\nرقم \nالقسط', dataKey: 'no' },
                  { header: 'Installment Date\nتاریخ القسط', dataKey: 'date' },
                  { header: 'Milestone', dataKey: 'milestone' },
                  { header: 'نسبة البناء'+'\nالدفعات/', dataKey: 'idk' },
                  { header: 'Payment Percentage\nنسبة الدفع', dataKey: 'perc' },
                  { header: 'Amount\nالمبلغ', dataKey: 'amount' },
                  { header: 'Amount VAT.\nقیمة ضریبة القیمة المضافة', dataKey: 'vat' },
                  { header: 'Incl. of VAT Amount\nالمبلغ شامل لضريبة القيمة المضافة', dataKey: 'wholeAmount' }
                ],
            });
            doc.addPage();


            doc.autoTable({
                theme: 'plain',
                startY: 20,
                rowPageBreak: 'avoid',
                margin: {top: 20, right: 5, bottom: 20, left: 5},
                color: [42, 50, 75],
                styles: { lineColor: '#2A324B', lineWidth: 0.2, cellPadding: 2 },
                columnStyles: { textColor: [42, 50, 75], 
                    eng: { halign: 'left', font: 'Amiri-Regular', cellWidth: 88, cellPadding: {top: 2, right: 2, bottom: 2, left: 0},lineWidth:{top: 0.2, right: 0.2, bottom: 0.2, left: 0} }, 
                    arab: { halign: 'right', font: 'Amiri-Regular', cellWidth: 88, cellPadding: {top: 2, right: 0, bottom: 2, left: 2},lineWidth:{top: 0.2, right: 0, bottom: 0.2, left: 0.2},overflow: 'hidden'},
                    num : { halign: 'right', font: 'Amiri-Regular', cellPadding: {top: 2, right: 2, bottom: 0, left: 5}, lineWidth:{top: 0.2, right: 0, bottom: 0.2, left: 0.2}},
                    numArab : { halign: 'right', font: 'Amiri-Regular', cellPadding: {top: 2, right: 5, bottom: 0, left: 2}, lineWidth:{top: 0.2, right: 0.2, bottom: 0.2, left: 0}} 
                },
                body: [
                    {
                        num: '3.',
                        eng: 'During a period of one hundred twenty (120) days from the date of signing this Offer to Purchase, the Vendor shall be entitled not to proceed in the sale of the Property at any time and to terminate this Offer to Purchase without the need to disclose the reason for termination, and without the need for notices or any legal proceedings or court judgment, and without any liability whatsoever. In case of such termination, and subject to the receipt of the Deposit in full, the Vendor shall refund the Deposit to the Purchaser without any interest and without any other compensation of any kind. The Purchaser hereby explicitly and finally waives any rights to claim any interest or compensation in respect of the foregoing that might be provided/allowed under any applicable laws. The signature by the Vendor on the Vendor’s Sales and Purchase Agreement shall constitute approval by the Vendor to sell the Property to the purchaser.', 
                        arab: 'خلال فترة مئة وعشرين )١٢٠(يوماً من تاريخ توقيع عرض الشراء هذا،\n يحق للبائع عدم المضي في بيع الوحدة العقارية في أي وقت يشاء،\n وإنهاء عرض الشراء هذا دون الحاجة إلى الكشف عن سبب الإنهاء،\n ودون الحاجة إلى إشعارات أو أي إجراءات قانونية أو حكم قضائي،\n ودون أي مسؤولية من أي نوع كانت. وفي حالة الإنهاء هذه، وشرط أن\n يكون قد تم قبض العربون بالكامل، يقوم البائع بإرجاع العربون\n إلى المشتري دون أية فوائد أو أي تعويض آخر من أي نوع كان.\n ويتنازل المشتري بموجبه بشكل نهائي وصريح عن أية حقوق في\n المطالبة بأية فائدة أو تعويض قد يكون منصوص عليهما أو مسموح ب\nهما بموجب أية قوانين معمول بها. ويعتبر توقيع البائع على ا\nتفاقية البيع والشراء تأكيداً منه على قبوله بيع الوحدة العقارية للمشتري.',
                        numArab: '.3'
                    },
                    {
                        num: '4.',
                        eng: 'The Purchaser shall provide complete and accurate contact information, as requested in this Offer to Purchase, and submit it to the Vendor on the signing hereof.',
                        arab: 'يجب على المشتري توفير معلومات كاملة ودقيقة للاتصال به، كما هو\n مطلوب في عرض الشراء هذا، وتقديمها للبائع عند توقيع هذا العرض.',
                        numArab: '.4'
                    
                    },
                    {
                        num: '5.',
                        eng: 'The Purchaser shall pay the above Deposit by means of payment acceptable to the Vendor on the signing hereof (or on any other date specified by the Vendor in writing). The Vendor may, at its sole discretion, request the Purchaser to pay the above Deposit by more than one mean of payment (such as, and without limitation, to pay a portion of the Deposit by credit card or cheque and the balance to be affected by wire transfer to the Vendor’s bank account). The Purchaser agrees to and accepts the foregoing provisions and that except in case of termination by the Vendor in accordance with Clause (3) above, the Deposit (or any paid portion thereof) is not refundable to the Purchaser for any reason whatsoever.',
                        arab: 'يلتزم المشتري بدفع العربون المذكور أعلاه  بواسطة وسيلة دفع\n مقبولة من البائع بتاريخ توقيع عرض الشراء هذا)أو بأي تاريخ\n آخر يحدده البائع خطياً.( ويحق للبائع، وفقاً لتقديره المطلق،\n الطلب من المشتري دفع العربون المذكور أعلاه بواسطة أكثر من\n وسيلة دفع )على سبيل المثال ودون حصر أن يتم دفع جزء من العربون\n بواسطة بطاقة الائتمان أو الشيك والرصيد المتبقي بواسطة حوالة\n بنكية الى حساب البائع المصرفي.( قبل المشتري ووافق على جميع\n ما تقدم وبأن العربون )أو أي جزء مدفوع منه(، باستثناء حالة إ\nنهاء عرض الشراء من قبل البائع وفقاً للبند (٣) أعلاه، هو غير\n قابل لاسترداد من قبل المشتري الى سبب من الأسباب.',
                        numArab: '.5',
                    },
                    {
                        num: '6.',
                        eng: 'In addition to the Purchase Price, the Purchaser agrees to pay, immediately upon the first request of the Vendor and without any delay, all pre-registration and/or final registration charges, and any other related amounts, as may be levied by the Land Department and ERES from time to time, for the transfer and registration of the Property with the Land Department. The pre-registration and/or final registration charges may be changed by the Land Department, ERES and/or the Vendor from time to time, and the Purchaser undertakes to pay any additional or changed charges. Moreover, the Purchase Price is exclusive of all taxes which shall be borne by the Purchaser.',
                        arab: 'بالإضافة إلى ثمن الشراء، يوافق المشتري على دفع الفوري عند أول\n طلب من البائع وبدون أي تـأخير كافة رسوم التسجيل المبدئي و/أو\n رسوم التسجيل النهائي وأية مبالغ أخرى ذات الصلة قد تفرضها دائرة\n الأراضي والاملاك وشركة الإمارات للحلول العقارية من وقت الى آخر\n لنقل ملكية وتسجيل الوحدة العقارية لدى دائرة الأراضي والاملاك. قد\n تقوم دائرة الأراضي والاملاك، شركة الإمارات للحلول العقارية و/أو\n البائع من وقت آخر بتعديل مبلغ التسجيل المبدئي و/أو رسوم\n التسجيل النهائي، ويتعهد المشتري بدفع أي رسم تسجيل إضافي أو\n معدّل. علاوة على ذلك فإن ثمن الشراء لا يشمل الضرائب وسوف\n يتحملها المشتري.',
                        numArab: '.6'},
                    {
                        num: '7.',
                        eng: 'The Purchaser shall sign the Vendor’s Sales and Purchase Agreement not later than (5) five working days from the date on which the Purchaser is notified by the Vendor to sign the Vendor’s Sales and Purchase Agreement. For the avoidance of doubt, the signature of the Purchaser on the Vendor’s Sales and Purchase Agreement shall not affect the rights of the Vendor under the above Clause (3). If the Purchaser fails to sign the Vendor’s Sale and Purchase Agreement within the prescribed period for any reason whatsoever, this Offer to Purchase shall automatically terminate upon the expiry of said period and the Deposit shall be forfeited to the Vendor, without need for notice or any further proceedings, legal or otherwise. The Vendor may, at its sole discretion, extend the aforesaid period for further period(s), in which case automatic termination of this Offer to Purchase and the right to forfeit the Deposit will apply on the first day following the extended period.',
                        arab: '. يجب على المشتري توقيع اتفاقية البيع والشراء الخاصة بالبائع في\n مهلة لا تتجاوز) ٥) خمسة أيام عمل من التاريخ الذي يتم فيه إخطار\n المشتري من قبل البائع لتوقيع اتفاقية البيع والشراء المذكورة.\n ومنعاً للشك، أن توقيع المشتري على اتفاقية البيع والشراء الخاصة\n بالبائع لا يؤثر على حقوق البائع بموجب البند (٣) اعلاه. وإذا\n تخلف المشتري عن توقيع اتفاقية البيع والشراء الخاصة بالبائع\n خلال المهلة المحددة لذلك لأي سبب كان، ينتهي عرض الشراء هذا\n تلقائياً عند انتهاء المهلة المذكورة، ويتم مصادرة العربون لمصلحة\n البائع، دون الحاجة إلى إخطار أو أية إجراءات إضافية، سواء\n قانونية أو غير ذلك. ويحق للبائع، وفقاً لتقديره المطلق، تمديد\n المهلة المذكورة لمهلة (أو مهل) أخرى، وفي هذه الحالة يسري\n الإنهاء التلقائي لعرض الشراء هذا والحق في مصادرة العربون\n اعتباراً من اليوم الأول الذي يلي انتهاء المهلة الممددة.',
                        numArab: '.7',
                    },
                    {
                        num: '8.',
                        eng: 'If any amount is paid by cheque and the cheque is not settled by the bank, if the pre- registration/registration charges and fees have not been settled by the Purchaser in a timely manner and/or if the Deposit has not been received by the Vendor in full within the time period specified in Clause (5) above, the Vendor may immediately terminate this Offer to Purchase without the need for notice or any further proceedings (legal or otherwise) or court judgment and any amounts received by the Vendor pursuant to this Offer to Purchase shall be absolutely forfeited by the Vendor. Such termination shall be without prejudice to the Vendor’s right to recover the Deposit amount in full and/or cheque value from the Purchaser or any additional amount as compensation. The Vendor may, at its sole discretion, allow the Purchaser to substitute the returned cheque by another form of payment acceptable to the Vendor or extend the time period for the full payment of the Deposit.',
                        arab: 'إذا تم دفع أي مبلغ بواسطة شيك ولم يتم تسديد قيمة الشيك من قبل\n البنك، و/أو في حال لم يقم المشتري أو تأخر في سداد رسوم ونفقات\n التسجيل المبدئي أو النهائي، و/أو إذا لم يتم استلام كامل العربون\n من قبل البائع في غضون المهلة المحددة في البند (٥) أعلاه، يعود\n للبائع انهاء عرض الشراء هذا فوراً دون الحاجة إلى إخطار أو أية\n إجراءات أخرى (سواء قانونية أو غير ذلك) أو حكم قضائي ويقوم\n البائع بمصادرة كافة المبالغ المقبوضة من قبله بمقتضى عرض الشراء\n هذا. ويكون هذا الإنهاء دون أي إخلال بحق البائع في تحصيل العربون\n بالكامل و/أو قيمة الشيك من المشتري أو تحصيل أي مبلغ إضافي\n كتعويض. ويمكن للبائع، وفقاً لتقديره المطلق، السماح للمشتري\n باستبدال الشيك المرتجع بأية وسيلة أخرى من وسائل الدفع تكون\n مقبولة من البائع أو تمديد المهلة المحددة لسداد كامل العربون.',
                        numArab: '.8'},
                    {
                        num: '9.',
                        eng: 'All payments made by the Purchaser pursuant to this Offer to Purchase shall be affected in Arab Emirates Dirham-AED (the lawful currency of the United Arab Emirates). In the event any payment is affected in any other currency for any installment, the credit to the Purchaser account would be given based on amount realized in AED by the Vendor. Accordingly, any shortfall/surplus due to exchange rate differences shall be recovered/adjusted towards the next installment payment.',
                        arab: 'إن كافة الدفعات التي يقوم بها المشتري بموجب عرض الشراء هذا\n تتم بالدرهم الإماراتي) العملة القانونية لدولة الإمارات العربية\n المتحدة. ( وفي حال تم سداد قيمة أي قسط بأية عملة أخرى، فيتم\n إيداع المبلغ في حساب المشتري وفقاً للقيمة المحّصلة من البائع\n بالدرهم الإماراتي. وعليه، فإن أي نقص/فائض في القيمة تنجم عن\n الفارق في سعر الصرف يتم إضافته/خصمه من قيمة القسط التالي.',
                        numArab: '.9'},
                    {
                        num: '10.',
                        eng: 'Subject to Clauses (3) and (7) above, and until the signing of the Vendor’s Sales and Purchase Agreement, this Offer to Purchase shall constitute a binding and enforceable contract on the Purchaser for the purchase of the Property subject to the terms and conditions of the Vendor’s Sales and Purchase Agreement, a copy of which has been made available to the Purchaser for inspection prior to the signing hereof. This Offer to Purchase is not transferable or assignable by the Purchaser and any such attempted transfer or assignment will be considered null and void.',
                        arab: 'مع الاحتفاظ بالحقوق المنصوص عليها بالبند ْين (٣) و (٧) أعلاه،\n وإلى أن يتم توقيع اتفاقية البيع والشراء الخاصة بالبائع، يشكل عرض\n الشراء هذا عقداً ملزماً للمشتري واجب النفاذ لشراء الوحدة\n العقارية وفقاً لأحكام وشروط اتفاقية البيع والشراء الخاصة بالبائع،\n والتي تم تزويد المشتري بنسخة منها للاطلاع عليها قبل توقيع عرض\n الشراء هذا. ان عرض الشراء هذا غير قابل للتحويل أو للتنازل من\n قبل المشتري، وتعتبر أية محاولة تحويل أو تنازل لاغية وباطلة.',
                        numArab: '.10'},
                    {
                        num: '11.',
                        eng: 'The Purchaser irrevocably and finally represents and confirms, at the Purchaser’s full responsibility, having complied with all regulations, laws and requirements in all relevant jurisdictions (inter alia all relevant exchange control requirements) and obtained all licenses, consents or permissions that are required to enter into and perform his/its obligations under this Offer to Purchase and/or under any document executed or to be executed pursuant to this Offer to Purchase.',
                        arab: 'يصرح المشتري ويؤكد على مسؤوليته الكاملة وبشكل نهائي غير قابل\n للرجوع عنه، بأنه امتثل لجميع القوانين والأنظمة والمتطلبات) ومن\n بينها جميع متطلبات الرقابة على الصرف ذات الصلة (في جميع الأنظمة\n القضائية والدول المختصة، واستحصل على جميع التراخيص والموافقات والأذونات\n المطلوبة للتوقيع على ولأداء التزاماته بموجب عرض الشراء هذا و/أو\n بموجب أي وثيقة حررت أو ستحرر وفقاً لعرض الشراء هذا.',
                        numArab: '.11'
                    },
                    {
                        num: '12.',
                        eng: 'The Purchaser guarantees at the Purchaser’s sole responsibility that all payments of any kind made under or pursuant to this Offer to Purchase are paid by funds of legitimate source and that the same are not the proceeds of any crime or illegal activity.',
                        arab: 'يضمن المشتري على كامل مسؤوليته بأن جميع المدفوعات من أي نوع\n كانت التي تتم بموجب أو وفقاً لعرض الشراء هذا هي أموال من مصدر\n مشروع وبأنها ليست ناتجة من أي جرم أو نشاط غير قانوني.',
                        numArab: '.12',
                    
                    },
                    {
                        num: '13.',
                        eng: 'The Purchaser irrevocably and finally agrees and authorizes the Vendor (including its parent company and their affiliates and subsidiaries) (together the “Group”) to collect, transfer, store and use the Purchaser’s information for any legitimate purpose inter alia for internal record keeping, to contact the Purchaser either directly or through any third-party service provider and/or to comply with any legal requirements. The Purchaser accepts and agrees that although the Group employs security measures in order to protect the information of its customers, the Group cannot guarantee that the security measures will protect against the loss or misuse of the Purchaser’s information and accordingly the Group shall bear no responsibility of any kind in respect thereof.',
                        arab: 'يوافق ويسمح المشتري للبائع (بما في ذلك شركته الأم والشركات\n التابعة والمتفرعة عنها) (معاً "المجموعة") بشكل نهائي غير قابل\n للرجوع عنه، بجمع ونقل وتخزين واستخدام المعلومات العائدة للمشتري\n ألية غاية مشروعة ومنها لحفظها في السجلات الداخلية و/أو للاتصال\n بالمشتري سواء بشكل مباشر أو عن طريق أي مزود خدمات من الغير\n و/أو لاستيفاء أية متطلبات قانونية. يقر المشتري ويوافق على أنه\n بالرغم من أن المجموعة تتخذ تدابير امنية من أجل حماية المعلومات\n العائدة لعملائها، فإن المجموعة لا يمكنها أن تضمن أن التدابير\n الأمنية ستوفر الحماية التامة ضد فقدان أو إساءة استخدام المعلومات\n الخاصة بالمشتري، وعليه فإن المجموعة لا تتحمل أية مسؤولية من أي\n نوع كانت بشأن ما تقدم.',
                        numArab: '.13'
                    },
                    {
                        num: '14.',
                        eng: 'Without prejudice to any other rights or remedies available to the Vendor, the Purchaser shall pay to the Vendor all costs and expenses of any kind (including without limitation and as applicable the legal fees, the notary public fees, the Dubai Land Department deregistration fees, etc.) incurred by the Vendor as a result of or in connection with (i) claiming, serving notices or suing to recover the payment of any sum due to the Vendor under this Offer to Purchase; or (ii) the enforcement of or the preservation of any rights of the Vendor hereunder.',
                        arab: 'دون المساس بأية حقوق أو وسائل أخرى متاحة للبائع، يتوجب على\n المشتري أن يدفع للبائع جميع التكاليف والنفقات من أي نوع كانت\n (بما في ذلك وليس على سبيل الحصر، ووفقاً للحال، رسوم ونفقات الإجراءات القضائية، ورسوم كاتب العدل، ورسوم شطب التسجيل لدى دائرة الأراضي الأملاك، الخ). التي تكبدها البائع بنتيجة أو فيما يتعلق بـ (أ) المطالبة أو\n توجيه الإخطارات أو التقاضي لتحصيل أي مبلغ مستحق للبائع بموجب\n عرض الشراء هذا؛ أو (ب)إنفاذ أو المحافظة على أي من حقوق البائع\n المذكورة في عرض الشراء هذا.',
                        numArab: '.14',
                    },
                    {
                        num: '15.',
                        eng: 'This Offer to Purchase shall be governed and construed in accordance with the laws of the Emirate of Dubai and the federal laws of the United Arab Emirates as applied in the Emirate of Dubai. All disputes between the parties hereto in respect of or in connection with this Offer to Purchase shall be referred to Dubai Courts. For the avoidance of doubt, the DIFC laws are not applicable and the DIFC Courts shall have no jurisdiction.',
                        arab: 'يخضع عرض الشراء هذا ويفسر وفقاً لقوانين إمارة دبي والقوانين الاتحادية\n لدولة الإمارات العربية المتحدة كما هي معمول بها في إمارة دبي. وتحال\n جميع المنازعات بين الطرفين فيما يختص أو يتعلق بعرض الشراء هذا\n لمحاكم دبي. ومنعاً للشك، فإن قوانين مركز دبي المالي العالمي غير\n مطبّقة ومحاكم مركز دبي المالي العالمي لا اختصاص لها.',
                        numArab: '.15',
                    },
                    {
                        num: '16.',
                        eng: 'This Offer to Purchase has been originally drafted in English and translated into Arabic. In the event of any discrepancy between the English version and the Arabic translation of this Offer to Purchase, the provisions set forth in English shall prevail and be applicable.',
                        arab: 'إن عرض الشراء هذا تم صياغته أصالً باللغة الإنكليزية وتمت ترجمته\n إلى اللغة العربية. وفي حال وجود أي تعارض أو تناقض فيما بين\n النسخة الإنكليزية والترجمة العربية لعرض الشراء هذا، فإن البنود\n المكتوبة باللغة الإنكليزية ترجح وتكون واجبة التطبيق.',
                        numArab: '.16',
                    },
                    {
                        num: '17.',
                        eng: 'All amounts to be paid to the Vendor pursuant to this Offer to Purchase are exclusive of the Value Added Tax (“VAT”) applicable in the United Arab Emirates. The Purchaser shall pay to the Vendor the applicable VAT without delay. Subject to the applicable laws and regulations, in the event any amount due to the Vendor pursuant to this Offer to Purchase is made in instalments or through deferred payments, the Vendor shall issue a VAT invoice to the Purchaser in respect of the due VAT upon the encashment by the Vendor of the relevant instalment or the deferred payment (as applicable).',
                        arab: 'إن جميع المبالغ المتوجبة الدفع للبائع بموجب عرض الشراء هذا لا\n تشمل ضريبة القيمة المضافة ("ضريبة القيمة المضافة") المطبّقة في\n دولة الإمارات العربية المتحدة. على المشتري أن يدفع إلى البائع\n ضريبة القيمة المضافة المطبّقة دون تأخير. مع مراعاة القوانين\n والأنظمة المرعية الأجراء، في حال سداد أي مبلغ مستحق للبائع وفقاً\n لعرض الشراء هذا على دفعات أو من خلال دفعات مؤجلة، سيقوم البائع\n بإصدار فاتورة ضريبة القيمة المضافة للمشتري فيما يتعلق بضريبة\n القيمة المضافة المستحقة عند قيام البائع باستيفاء الدفعة ذات\n الصلة أو الدفعة المؤجلة (كما تكون عليه الحال).',
                        numArab: '.17',
                    }
                ],
                columns: [
                  { header: '', dataKey: 'num' },
                  { header: '', dataKey: 'eng' },
                  { header: '', dataKey: 'arab' },
                  { header: '', dataKey: 'numArab' }
                ],
            });
            let agencyName = this.data.opportunity.Agency__r != undefined ? this.data.opportunity.Agency__r.Name : '';
            let agencyNameArabic = this.data.opportunity.Agency__r != undefined ? this.data.opportunity.Agency__r.Account_Name_Arabic__c : '';
            let agentName = this.data.opportunity.Agent__r != undefined ? this.data.opportunity.Agent__r.Name : '';
            let agentNameArabic = (this.data.opportunity.Agent__r != undefined ? this.data.opportunity.Agent__r.Contact_First_Name_Arabic__c: '')+' '+(this.data.opportunity.Agent__r != undefined ? this.data.opportunity.Agent__r.Contact_Middle_Name_Arabic__c : '')+' '+(this.data.opportunity.Agent__r != undefined ? this.data.opportunity.Agent__r.Contact_Last_Name_Arabic__c : '');
            let agentInfoSection = 
                'Agents Information\n\nAre you being assisted by any of Vendor’s registered agents: '+this.data.agentAssistEng+
                '\nAgency Name: '+agencyName+
                '\nAgency Representative’s Name: '+agentName+
                '\nAgency Representative’s Signature:';

            let agentInfoSectionArabic = 
                'معلومات عن الوسطاء\n\n'+
                'هل تمت مساعدتكم من قبل أي من الوسطاء المسجلين مع البائع:'+this.data.agentAssistArabic+
                '\nاسم الوسيط العقاري: '+agencyNameArabic+
                '\nاسم ممثل الوسيط العقاري: '+agentNameArabic+
                '\n:توقيع ممثل الوسيط العقاري';
            agentInfoSectionArabic = agentInfoSectionArabic.replaceAll("undefined", '');

            let signatureSection = 
            '\n\n___________________________\nPurchaser 1 Signature\n\n'+this.data.opportunity.Account.Name;


            let signatureSectionArabic = 
            '\n\n___________________________\nتوقیع المشتري رقم 1\n\n'+(this.data.opportunity.Account.IsPersonAccount ? (this.data.opportunity.Account.Contact_First_Name_Arabic__pc+' '+this.data.opportunity.Account.Contact_Middle_Name_Arabic__pc+' '+this.data.opportunity.Account.Contact_Last_Name_Arabic__pc):this.data.opportunity.Account.Account_Name_Arabic__c);
            for(let i = 0; i < this.data.jointOwners.length; i++){
                let number = i+2;
                signatureSection=signatureSection+'\n\n\n\n___________________________\nPurchaser '+ number + ' Signature\n\n'+this.data.jointOwners[i].Name;
                signatureSectionArabic=signatureSectionArabic+'\n\n\n\n___________________________\n'+ number + ' توقیع المشتري رقم \n\n'+(this.data.jointOwners[i].IsPersonAccount ? (this.data.jointOwners[i].Contact_First_Name_Arabic__pc+' '+this.data.jointOwners[i].Contact_Middle_Name_Arabic__pc+' '+this.data.jointOwners[i].Contact_Last_Name_Arabic__pc):this.data.jointOwners[i].Account_Name_Arabic__c);
            }
            signatureSection=signatureSection+'\n\n\n\n___________________________\nSales Advisor Name & Signature (on Behalf of the Vendor)\n\n'+this.data.opportunity.Owner.Name;

            signatureSectionArabic=signatureSectionArabic+'\n\n\n\n___________________________\nاسم وتوقيع مستشار المبيعات (ممثل البائع)\n\n'+this.data.opportunity.Owner.Name;
            signatureSection = signatureSection.replaceAll("undefined", '');
            signatureSectionArabic = signatureSectionArabic.replaceAll("undefined", '');

            doc.autoTable({
                theme: 'plain',
                startY: 70,
                margin: {top: 20, right: 5, bottom: 20, left: 5},
                color: [42, 50, 75],
                styles: { lineColor: '#2A324B', lineWidth: 0.2, cellPadding: 2 },
                columnStyles: { textColor: [42, 50, 75], eng: { halign: 'left', font: 'Amiri-Regular', cellWidth: 100 }, arab: { halign: 'right', font: 'Amiri-Regular', cellWidth: 100,overflow: 'hidden' } },
                body: [
                    { eng: agentInfoSection, arab: agentInfoSectionArabic},
                    { eng: signatureSection, arab: signatureSectionArabic}
                ],
                columns: [
                    { header: '', dataKey: 'eng' },
                    { header: '', dataKey: 'arab' },
                ],
            });
            // doc.addPage();
            // doc.setFontSize(14);
            // doc.text(95,20,'Floor Plan',);

            // let photoTableBody = [];
            // let photoTableColumns = [];
            // let imgWidth = 95;
            // let photoTableColumnStyles = { one: { halign: 'center', font: 'Amiri-Regular', cellWidth: 100, minCellHeight: 120 }, two: { halign: 'center', font: 'Amiri-Regular', cellWidth: 100, minCellHeight: 120} };

            // if(this.data.imgUrls != undefined){

            //     const sortedImgUrls = this.data.imgUrls.sort((a, b) => a.order - b.order);
            //     if(sortedImgUrls.length === 1){
            //         photoTableBody=[{one: sortedImgUrls[0].desc}];
            //         photoTableColumns=[{ header: '', dataKey: 'one' }];
            //         photoTableColumnStyles.one.cellWidth = 200;
            //         imgWidth = 190;
            //     } else {
            //         photoTableColumns=[
            //             { header: '', dataKey: 'one' },
            //             { header: '', dataKey: 'two' },
            //         ];
            //         for (let i = 0; i < sortedImgUrls.length; i += 2) {
            //             const obj = { one: '', two: '' };
            //             obj.one = sortedImgUrls[i].desc;
            //             if (sortedImgUrls[i + 1]) {
            //                 obj.two = sortedImgUrls[i + 1].desc;
            //             }
            //             photoTableBody.push(obj);
            //         }
            //     }
            //     let counter = 0;
            //     doc.autoTable({
            //         theme: 'plain',
            //         startY: 25,
            //         styles: { lineColor: '#2A324B', lineWidth: 0, cellPadding: 2 },
            //         margin: 5,
            //         columnStyles: photoTableColumnStyles,
            //         didDrawCell: (data) => {
            //             if (data.section === 'body' && this.data.imgUrls[counter] != undefined) {
            //                 let imgData = 'data:image/jpeg;base64,'+ this.data.imgUrls[counter].base64;
            //                 doc.addImage(imgData, 'PNG', data.cell.x + 2, data.cell.y + 10, imgWidth, 0);
            //                 counter++;
            //             }
            //         },
            //         body: photoTableBody,
            //         columns: photoTableColumns,
            //     });
            // }


            // doc.setFontSize(8);
            // doc.text(5,270,'Floor Plan 1. All dimensions are in imperial and metric, and measured from finish to finish excluding construction tolerances. 2. All materials, dimensions, and drawings are \napproximate only. 3. Information is subject to change without notice, at developer’s absolute discretion. 4. Actual area may vary from the stated area. 5. Drawings not to scale. \n6. All images used are for illustrative purposes only and do not represent the actual size, features, specifications, fittings, and furnishings. 7. The developer reserves the \nright to make revisions / alterations, at it’s absolute discretion, without any liability whatsoever.');

            const pageCount = doc.internal.getNumberOfPages()

            doc.setFont('helvetica');
            doc.setFontSize(14);
            for (var x = 1; x <= pageCount; x++) {
                doc.setPage(x)
                doc.setFontSize(14);
                doc.text(5,290,'Signed by the Purchaser _____________________');
                doc.text(202,290, String(x));
                doc.setFontSize(17);
                doc.text(10, 10, 'OFFER TO PURCHASE');

                doc.addImage(logoImgData, 'PNG', 150, 5, 50, 12);
            }
            let jsPdfArrayBuffer = doc.output('arraybuffer');

            let blob;
            if(this.data.pdfData != undefined && this.data.pdfData != ''){

                const binaryString = window.atob(this.data.pdfData);
                const len = binaryString.length;
                const bytes = new Uint8Array(len);
                for (let i = 0; i < len; i++) {
                    bytes[i] = binaryString.charCodeAt(i);
                }
                let unitPdfArrayBuffer = bytes.buffer;
    
                async function combinePdfs(jsPdfArrayBuffer, unitPdfArrayBuffer) {
                    const jsPdfDoc = await PDFDocument.load(jsPdfArrayBuffer);
                    const unitPdfDoc = await PDFDocument.load(unitPdfArrayBuffer);
        
                    const combinedPdfDoc = await PDFDocument.create();
        
                    const jsPdfPages = await combinedPdfDoc.copyPages(jsPdfDoc, jsPdfDoc.getPageIndices());
                    jsPdfPages.forEach((page) => combinedPdfDoc.addPage(page));
        
                    const unitPdfPages = await combinedPdfDoc.copyPages(unitPdfDoc, unitPdfDoc.getPageIndices());
                    unitPdfPages.forEach((page) => combinedPdfDoc.addPage(page));
        
                    const combinedPdfBytes = await combinedPdfDoc.save();
                    return combinedPdfBytes;
                }
                const combinedPdfBytes = await combinePdfs(jsPdfArrayBuffer, unitPdfArrayBuffer);
            
                blob = new Blob([combinedPdfBytes], { type: 'application/pdf' });
            } else {
                blob = new Blob([jsPdfArrayBuffer], { type: 'application/pdf' });
            }

            const link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            link.download = this.data.opportunity.Name + ".pdf";
            link.click();
    }

    @api
    async generate(){
        try {
            if(this.recordId != null){
                getData({oppId : this.recordId})
                .then(result => {
                    this.data = result;
                    this.generatePDF();
                })
                .catch(error => {
                    if(error && error.body){
                     const evt = new ShowToastEvent({
                           title: error.body.message,
                            variant: 'error',
                        });
                        this.dispatchEvent(evt);
                    }
                });
            }
            
        }
        catch(error) {
            console.log(error);
            console.error(JSON.stringify(error));
        }
    }

    addCommasToNumber(number) {
        let numStr = number.toString();
    
        let parts = numStr.split('.');
    
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    
        return parts.join('.');
    }

    findArabicLabelByEnglishValue(englishValue, translationMap) {
        for (let i = 0; i < translationMap.length; i++) {
          let mapping = translationMap[i];
          for (let key in mapping) {
            if (mapping.hasOwnProperty(key) && key === englishValue) {
              return mapping[key];
            }
          }
        }
        return undefined;
      }
}