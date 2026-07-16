import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getMonthlyActivityData from '@salesforce/apex/OpportunityMonthlyActivityController.getMonthlyActivityData';
import getAvailableYears from '@salesforce/apex/OpportunityMonthlyActivityController.getAvailableYears';

export default class OpportunityMonthlyChart extends LightningElement {
    @track chart;
    @track chartData = [];
    @track availableYears = [];
    @track selectedYear = new Date().getFullYear();
    @track isLoading = true;
    @track error;


    @wire(getAvailableYears)
    wiredYears({ error, data }) {
        if (data) {
            this.availableYears = data;
            if (data.length > 0 && !this.selectedYear) {
                this.selectedYear = data[0];
            }
        } else if (error) {
            this.error = error;
            console.error('Error loading years:', error);
        }
    }

    @wire(getMonthlyActivityData, { year: '$selectedYear' })
    wiredChartData({ error, data }) {
        console.log('wiredChartData called with:', { error, data });
        console.log('hasData before:', this.hasData);
        if (data) {
            this.chartData = data;
            this.error = undefined;
            console.log('Chart data received:', data);
            console.log('hasData after:', this.hasData);
            console.log('Data length:', data.length);
            // Add a small delay to ensure DOM has updated
            setTimeout(() => {
                this.renderChart();
            }, 100);
        } else if (error) {
            this.error = error;
            console.error('Error loading chart data:', error);
        }
        this.isLoading = false;
    }

    connectedCallback() {
        console.log('Component connected to DOM');
        console.log('Template available:', !!this.template);
        this.renderChart();
    }


    handleYearChange(event) {
        this.selectedYear = parseInt(event.target.value);
        this.isLoading = true;
    }

    handlePrint() {
        console.log('Print button clicked');
        
        // Get the canvas element
        const canvas = this.template.querySelector('canvas');
        if (!canvas) {
            console.error('Canvas not found for printing');
            alert('Chart not ready for printing. Please wait for the chart to load.');
            return;
        }
        
        console.log('Canvas found:', canvas);
        console.log('Canvas dimensions:', canvas.width, 'x', canvas.height);
        
        try {
            // Get canvas data as image directly (this should work with the current setup)
            const canvasDataURL = canvas.toDataURL('image/png');
            console.log('Canvas data URL length:', canvasDataURL.length);
            
            if (canvasDataURL.length < 100) {
                console.error('Canvas data is empty or invalid');
                alert('Chart data not available for printing. Please ensure the chart is fully loaded.');
                return;
            }
            
            // Create a simple print window
            const printWindow = window.open('', '_blank', 'width=1000,height=700');
            
            if (!printWindow) {
                alert('Please allow popups for this site to enable printing.');
                return;
            }
            
            console.log('Print window opened');
            
            // Create print content using DOM methods (LWS compatible)
            const doc = printWindow.document;
            
            // Set document title
            doc.title = `Monthly Sales Report - ${this.selectedYear}`;
            
            // Create head element
            const head = doc.createElement('head');
            const style = doc.createElement('style');
            style.textContent = `
                @page {
                    size: A4 landscape;
                    margin: 0.5in;
                }
                
                body { 
                    font-family: Arial, sans-serif; 
                    margin: 0; 
                    padding: 20px; 
                    text-align: center; 
                    background: white;
                    page-break-inside: avoid;
                }
                
                .print-container {
                    page-break-inside: avoid;
                    max-width: 100%;
                }
                
                h1 { 
                    color: #333; 
                    margin-bottom: 10px; 
                    font-size: 24px; 
                    page-break-after: avoid;
                }
                
                h2 { 
                    color: #666; 
                    margin-bottom: 20px; 
                    font-size: 16px; 
                    page-break-after: avoid;
                }
                
                img { 
                    max-width: 100%; 
                    height: auto; 
                    border: 1px solid #ddd; 
                    margin: 20px 0; 
                    background: white;
                    page-break-inside: avoid;
                    page-break-after: avoid;
                }
                
                .legend { 
                    margin: 20px 0; 
                    page-break-inside: avoid;
                    page-break-after: avoid;
                }
                
                .legend-item { 
                    display: inline-block; 
                    margin: 0 20px; 
                }
                
                .legend-color { 
                    width: 20px; 
                    height: 20px; 
                    display: inline-block; 
                    margin-right: 5px; 
                    border: 1px solid #333; 
                }
                
                .booked { background-color: #3498db; }
                .sold { background-color: #2ecc71; }
                
                .summary { 
                    margin-top: 20px; 
                    padding: 15px; 
                    background-color: #f8f9fa; 
                    border-radius: 5px; 
                    page-break-inside: avoid;
                }
                
                .summary-item { 
                    display: inline-block; 
                    margin: 0 20px; 
                    text-align: center; 
                }
                
                .summary-title { 
                    font-weight: bold; 
                    margin-bottom: 5px; 
                }
                
                .booked-title { color: #3498db; }
                .sold-title { color: #2ecc71; }
                .in-progress-title { color: #ff9800; }
                .total-title { color: #0070d2; }
                
                @media print {
                    body { margin: 0; padding: 10px; }
                    .print-container { page-break-inside: avoid; }
                    img { page-break-inside: avoid; }
                }
            `;
            head.appendChild(style);
            
            // Create body element
            const body = doc.createElement('body');
            
            // Create print container
            const printContainer = doc.createElement('div');
            printContainer.className = 'print-container';
            
            // Create title
            const h1 = doc.createElement('h1');
            h1.textContent = 'Monthly Sales Report';
            printContainer.appendChild(h1);
            
            const h2 = doc.createElement('h2');
            h2.textContent = `Year: ${this.selectedYear}`;
            printContainer.appendChild(h2);
            
            // Create chart image
            const img = doc.createElement('img');
            img.src = canvasDataURL;
            img.alt = 'Monthly Activity Chart';
            img.onload = () => {
                console.log('Image loaded successfully');
                setTimeout(() => printWindow.print(), 1000);
            };
            img.onerror = () => {
                console.error('Image failed to load');
                alert('Failed to load chart image');
            };
            printContainer.appendChild(img);
            
            // Create legend
            const legend = doc.createElement('div');
            legend.className = 'legend';
            
            const bookedLegend = doc.createElement('div');
            bookedLegend.className = 'legend-item';
            bookedLegend.innerHTML = '<div class="legend-color booked"></div><span>Booked</span>';
            legend.appendChild(bookedLegend);
            
            const soldLegend = doc.createElement('div');
            soldLegend.className = 'legend-item';
            soldLegend.innerHTML = '<div class="legend-color sold"></div><span>Sold</span>';
            legend.appendChild(soldLegend);
            
            printContainer.appendChild(legend);
            
            // Create summary
            const summary = doc.createElement('div');
            summary.className = 'summary';
            
            const bookedSummary = doc.createElement('div');
            bookedSummary.className = 'summary-item';
            bookedSummary.innerHTML = `
                <div class="summary-title booked-title">Booked</div>
                <div>${this.totalBookedValue}</div>
                <div>${this.totalBookedCount} units</div>
            `;
            summary.appendChild(bookedSummary);
            
            const soldSummary = doc.createElement('div');
            soldSummary.className = 'summary-item';
            soldSummary.innerHTML = `
                <div class="summary-title sold-title">Sold</div>
                <div>${this.totalSoldValue}</div>
                <div>${this.totalSoldCount} units</div>
            `;
            summary.appendChild(soldSummary);
            
            const inProgressSummary = doc.createElement('div');
            inProgressSummary.className = 'summary-item';
            inProgressSummary.innerHTML = `
                <div class="summary-title in-progress-title">In Progress</div>
                <div>${this.totalInProgressValue}</div>
                <div>${this.totalInProgressCount} units</div>
            `;
            summary.appendChild(inProgressSummary);
            
            printContainer.appendChild(summary);
            
            // Append print container to body
            body.appendChild(printContainer);
            
            // Append head and body to document
            doc.documentElement.appendChild(head);
            doc.documentElement.appendChild(body);
            
            console.log('Print content written to window');
            
        } catch (error) {
            console.error('Error in print function:', error);
            alert('Error generating print preview: ' + error.message);
        }
    }

    renderChart() {
        console.log('renderChart called');
        console.log('Template:', this.template);
        console.log('Template HTML:', this.template.innerHTML);
        
        const canvas = this.template.querySelector('canvas');
        console.log('Canvas query result:', canvas);
        
        if (!canvas) {
            console.log('Canvas not found - checking all elements');
            const allElements = this.template.querySelectorAll('*');
            console.log('All elements found:', allElements);
            return;
        }

        console.log('Canvas found:', canvas);
        console.log('Canvas dimensions:', canvas.width, 'x', canvas.height);
        console.log('Canvas style:', canvas.style.cssText);

        const ctx = canvas.getContext('2d');
        console.log('Canvas context:', ctx);
        
        // Set canvas size to full width with high-DPI support
        const containerWidth = canvas.parentElement.clientWidth || 1200;
        const devicePixelRatio = window.devicePixelRatio || 1;
        const displayWidth = containerWidth;
        const displayHeight = 400;
        
        // Set the actual canvas size in memory (scaled up for high-DPI)
        canvas.width = displayWidth * devicePixelRatio;
        canvas.height = displayHeight * devicePixelRatio;
        
        // Set the display size (CSS pixels)
        canvas.style.width = displayWidth + 'px';
        canvas.style.height = displayHeight + 'px';
        canvas.style.border = '1px solid #ddd'; // Subtle border
        
        // Scale the canvas back down using CSS
        canvas.style.width = '100%';
        canvas.style.height = '400px';
        
        console.log('Canvas after sizing:', canvas.width, 'x', canvas.height);
        
        // Scale the context to match the device pixel ratio
        ctx.scale(devicePixelRatio, devicePixelRatio);
        
        // Clear canvas
        ctx.clearRect(0, 0, displayWidth, displayHeight);
        
        // Draw a grouped bar chart with Booked and Sold for each month
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        
        // Use actual data from the controller - using values for bar heights
        let bookedData = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        let soldData = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        
        if (this.chartData && this.chartData.length > 0) {
            this.chartData.forEach(item => {
                const monthIndex = item.month - 1; // Convert 1-12 to 0-11
                if (monthIndex >= 0 && monthIndex < 12) {
                    bookedData[monthIndex] = item.bookedValue || 0;
                    soldData[monthIndex] = item.soldValue || 0;
                }
            });
        }
        
        console.log('Using actual data - Booked:', bookedData, 'Sold:', soldData);
        
        const barWidth = 50; // Reduced width for each bar to fit 12 months
        const barSpacing = 5; // Minimal space between booked and sold bars (same month)
        const monthSpacing = (displayWidth - 100) / 12; // Space for 12 months
        const maxValue = Math.max(...bookedData, ...soldData) || 1; // Avoid division by zero
        const chartHeight = 300;
        const chartWidth = displayWidth - 100;
        const startX = 50;
        const startY = 60; // Reduced since we simplified labels
        
        // Draw bars for each month
        months.forEach((month, monthIndex) => {
            const monthX = startX + monthIndex * monthSpacing;
            const groupWidth = (barWidth * 2) + barSpacing;
            const groupCenter = monthX + groupWidth / 2;
            
            // Draw Booked bar (blue) - FIRST
            const bookedValue = bookedData[monthIndex] || 0;
            const bookedHeight = (bookedValue / maxValue) * chartHeight;
            const bookedX = monthX;
            const bookedY = startY + chartHeight - bookedHeight;
            
            ctx.fillStyle = '#3498db'; // Blue for Booked
            ctx.fillRect(bookedX, bookedY, barWidth, bookedHeight);
            
            // Draw Sold bar (green) - SECOND (right next to Booked)
            const soldValue = soldData[monthIndex] || 0;
            const soldHeight = (soldValue / maxValue) * chartHeight;
            const soldX = monthX + barWidth + barSpacing;
            const soldY = startY + chartHeight - soldHeight;
            
            ctx.fillStyle = '#2ecc71'; // Green for Sold
            ctx.fillRect(soldX, soldY, barWidth, soldHeight);
            
            // Draw values on top of bars in simple format
            ctx.fillStyle = '#000';
            ctx.font = 'bold 11px Arial, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            
            // Get counts for display labels
            let bookedCount = 0;
            let soldCount = 0;
            
            if (this.chartData && this.chartData.length > 0) {
                const monthData = this.chartData.find(item => item.month === monthIndex + 1);
                if (monthData) {
                    bookedCount = monthData.bookedCount || 0;
                    soldCount = monthData.soldCount || 0;
                }
            }
            
            if (bookedValue > 0) {
                // Format value without currency symbol
                const formattedValue = new Intl.NumberFormat('en-US', {
                    minimumFractionDigits: 0,
                    maximumFractionDigits: 0
                }).format(bookedValue);
                
                // Center text over the bar
                const textX = bookedX + barWidth/2;
                const textY = bookedY - 20;
                
                // Show units on first line, value on second line
                ctx.fillText(`${bookedCount}`, textX, textY);
                ctx.fillText(formattedValue, textX, textY + 12);
            }
            
            if (soldValue > 0) {
                // Format value without currency symbol
                const formattedValue = new Intl.NumberFormat('en-US', {
                    minimumFractionDigits: 0,
                    maximumFractionDigits: 0
                }).format(soldValue);
                
                // Center text over the bar
                const textX = soldX + barWidth/2;
                const textY = soldY - 20;
                
                // Show units on first line, value on second line
                ctx.fillText(`${soldCount}`, textX, textY);
                ctx.fillText(formattedValue, textX, textY + 12);
            }
            
            // Draw month label below bars (centered under both bars)
            ctx.font = 'bold 12px Arial, sans-serif';
            ctx.fillText(month, groupCenter, startY + chartHeight + 20);
        });
        
        // Draw axes
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(startX, startY);
        ctx.lineTo(startX, startY + chartHeight);
        ctx.lineTo(startX + chartWidth, startY + chartHeight);
        ctx.stroke();
        
        // Draw legend
        ctx.font = 'bold 12px Arial, sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        
        // Booked legend
        ctx.fillStyle = '#3498db';
        ctx.fillRect(startX, startY - 30, 15, 15);
        ctx.fillStyle = '#000';
        ctx.fillText('Booked', startX + 20, startY - 20);
        
        // Sold legend
        ctx.fillStyle = '#2ecc71';
        ctx.fillRect(startX + 80, startY - 30, 15, 15);
        ctx.fillStyle = '#000';
        ctx.fillText('Sold', startX + 100, startY - 20);
        
        console.log('Manual chart drawn successfully');
    }

    addDataLabels() {
        if (!this.chart || !this.chartData) return;

        // Add value labels above bars
        this.chart.data.datasets.forEach((dataset, datasetIndex) => {
            dataset.data.forEach((value, index) => {
                if (value > 0) {
                    const meta = this.chart.getDatasetMeta(datasetIndex);
                    const bar = meta.data[index];
                    if (bar) {
                        const x = bar.x;
                        const y = bar.y - 10;
                        
                        // Create text element
                        const ctx = this.chart.ctx;
                        ctx.save();
                        ctx.font = 'bold 10px Arial';
                        ctx.fillStyle = '#000';
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'bottom';
                        
                        const label = new Intl.NumberFormat('en-US', {
                            minimumFractionDigits: 0,
                            maximumFractionDigits: 0
                        }).format(value);
                        
                        ctx.fillText(label, x, y);
                        ctx.restore();
                    }
                }
            });
        });
    }

    get hasData() {
        return this.chartData && this.chartData.length > 0;
    }

    get hasError() {
        return this.error;
    }

    get yearOptions() {
        return this.availableYears.map(year => ({
            label: year.toString(),
            value: year
        }));
    }

    get totalBookedValue() {
        if (!this.chartData || this.chartData.length === 0) return 'AED 0';
        const total = this.chartData.reduce((sum, item) => sum + (item.bookedValue || 0), 0);
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'AED',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(total);
    }

    get totalSoldValue() {
        if (!this.chartData || this.chartData.length === 0) return 'AED 0';
        const total = this.chartData.reduce((sum, item) => sum + (item.soldValue || 0), 0);
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'AED',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(total);
    }


    get totalBookedCount() {
        if (!this.chartData || this.chartData.length === 0) return 0;
        return this.chartData.reduce((sum, item) => sum + (item.bookedCount || 0), 0);
    }

    get totalSoldCount() {
        if (!this.chartData || this.chartData.length === 0) return 0;
        return this.chartData.reduce((sum, item) => sum + (item.soldCount || 0), 0);
    }

    get totalInProgressValue() {
        if (!this.chartData || this.chartData.length === 0) return 'AED 0';
        const bookedTotal = this.chartData.reduce((sum, item) => sum + (item.bookedValue || 0), 0);
        const soldInCurrentYearTotal = this.chartData.reduce((sum, item) => sum + (item.soldInCurrentYearValue || 0), 0);
        const difference = bookedTotal - soldInCurrentYearTotal;
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'AED',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(difference);
    }

    get totalInProgressCount() {
        if (!this.chartData || this.chartData.length === 0) return 0;
        const bookedTotal = this.chartData.reduce((sum, item) => sum + (item.bookedCount || 0), 0);
        const soldInCurrentYearTotal = this.chartData.reduce((sum, item) => sum + (item.soldInCurrentYearCount || 0), 0);
        return bookedTotal - soldInCurrentYearTotal;
    }

}