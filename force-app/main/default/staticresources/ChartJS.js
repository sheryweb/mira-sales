// Simplified Chart.js implementation for Salesforce LWC
// This is a minimal implementation that provides the core Chart functionality

window.Chart = (function() {
    'use strict';
    
    const Chart = function(ctx, config) {
        this.ctx = ctx;
        this.config = config;
        this.data = config.data;
        this.options = config.options || {};
        this.plugins = config.plugins || [];
        this.chart = this;
        
        this.init();
    };
    
    Chart.prototype.init = function() {
        this.setupCanvas();
        this.render();
    };
    
    Chart.prototype.setupCanvas = function() {
        const canvas = this.ctx.canvas;
        const container = canvas.parentElement;
        
        // Set responsive size
        if (this.options.responsive !== false) {
            const resizeObserver = new ResizeObserver(entries => {
                this.resize();
            });
            resizeObserver.observe(container);
        }
    };
    
    Chart.prototype.resize = function() {
        const canvas = this.ctx.canvas;
        const container = canvas.parentElement;
        const rect = container.getBoundingClientRect();
        
        canvas.width = rect.width;
        canvas.height = rect.height;
        
        this.render();
    };
    
    Chart.prototype.render = function() {
        const ctx = this.ctx;
        const data = this.data;
        const options = this.options;
        
        // Clear canvas
        ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
        
        // Calculate dimensions
        const padding = 40;
        const chartWidth = ctx.canvas.width - (padding * 2);
        const chartHeight = ctx.canvas.height - (padding * 2);
        const barWidth = chartWidth / (data.labels.length * 3); // 3 bars per group (booked, sold, spacing)
        
        // Draw axes
        this.drawAxes(ctx, padding, chartWidth, chartHeight);
        
        // Draw bars
        this.drawBars(ctx, data, padding, chartWidth, chartHeight, barWidth);
        
        // Draw legend
        if (options.plugins && options.plugins.legend && options.plugins.legend.display !== false) {
            this.drawLegend(ctx, data.datasets, padding);
        }
    };
    
    Chart.prototype.drawAxes = function(ctx, padding, chartWidth, chartHeight) {
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 1;
        
        // X-axis
        ctx.beginPath();
        ctx.moveTo(padding, padding + chartHeight);
        ctx.lineTo(padding + chartWidth, padding + chartHeight);
        ctx.stroke();
        
        // Y-axis
        ctx.beginPath();
        ctx.moveTo(padding, padding);
        ctx.lineTo(padding, padding + chartHeight);
        ctx.stroke();
        
        // Y-axis labels
        const maxValue = Math.max(...this.data.datasets.flatMap(dataset => dataset.data));
        const step = maxValue / 5;
        
        ctx.fillStyle = '#666';
        ctx.font = '12px Arial';
        ctx.textAlign = 'right';
        
        for (let i = 0; i <= 5; i++) {
            const value = step * i;
            const y = padding + chartHeight - (i * chartHeight / 5);
            
            ctx.fillText(this.formatCurrency(value), padding - 10, y + 4);
        }
    };
    
    Chart.prototype.drawBars = function(ctx, data, padding, chartWidth, chartHeight, barWidth) {
        const maxValue = Math.max(...data.datasets.flatMap(dataset => dataset.data));
        
        data.datasets.forEach((dataset, datasetIndex) => {
            ctx.fillStyle = dataset.backgroundColor || '#3498db';
            ctx.strokeStyle = dataset.borderColor || '#2980b9';
            ctx.lineWidth = dataset.borderWidth || 1;
            
            dataset.data.forEach((value, index) => {
                const barHeight = (value / maxValue) * chartHeight;
                const x = padding + (index * chartWidth / data.labels.length) + (datasetIndex * barWidth);
                const y = padding + chartHeight - barHeight;
                
                // Draw bar
                ctx.fillRect(x, y, barWidth * 0.8, barHeight);
                ctx.strokeRect(x, y, barWidth * 0.8, barHeight);
                
                // Draw value label
                if (value > 0) {
                    ctx.fillStyle = '#000';
                    ctx.font = 'bold 10px Arial';
                    ctx.textAlign = 'center';
                    ctx.fillText(this.formatCurrency(value), x + (barWidth * 0.4), y - 5);
                    ctx.fillStyle = dataset.backgroundColor || '#3498db';
                }
            });
        });
        
        // Draw X-axis labels
        ctx.fillStyle = '#666';
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        
        data.labels.forEach((label, index) => {
            const x = padding + (index * chartWidth / data.labels.length) + (chartWidth / data.labels.length / 2);
            ctx.fillText(label, x, padding + chartHeight + 20);
        });
    };
    
    Chart.prototype.drawLegend = function(ctx, datasets, padding) {
        const legendX = padding;
        const legendY = 20;
        const itemHeight = 20;
        
        datasets.forEach((dataset, index) => {
            const y = legendY + (index * itemHeight);
            
            // Draw color box
            ctx.fillStyle = dataset.backgroundColor || '#3498db';
            ctx.fillRect(legendX, y - 8, 12, 12);
            ctx.strokeStyle = dataset.borderColor || '#2980b9';
            ctx.strokeRect(legendX, y - 8, 12, 12);
            
            // Draw label
            ctx.fillStyle = '#333';
            ctx.font = '12px Arial';
            ctx.textAlign = 'left';
            ctx.fillText(dataset.label, legendX + 20, y);
        });
    };
    
    Chart.prototype.formatCurrency = function(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'AED',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(value);
    };
    
    Chart.prototype.destroy = function() {
        // Cleanup if needed
    };
    
    return Chart;
})();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = window.Chart;
}
