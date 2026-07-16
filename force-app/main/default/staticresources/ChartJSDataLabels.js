// Chart.js DataLabels Plugin for Salesforce LWC
// This is a simplified implementation of the datalabels plugin

window.ChartDataLabels = (function() {
    'use strict';
    
    const ChartDataLabels = {
        id: 'datalabels',
        
        afterDatasetsDraw: function(chart) {
            const ctx = chart.ctx;
            const data = chart.data;
            const options = chart.options.plugins.datalabels || {};
            
            if (!options.display) return;
            
            const padding = 40;
            const chartWidth = ctx.canvas.width - (padding * 2);
            const chartHeight = ctx.canvas.height - (padding * 2);
            const maxValue = Math.max(...data.datasets.flatMap(dataset => dataset.data));
            
            data.datasets.forEach((dataset, datasetIndex) => {
                dataset.data.forEach((value, index) => {
                    if (value === 0) return;
                    
                    const barHeight = (value / maxValue) * chartHeight;
                    const barWidth = chartWidth / (data.labels.length * 3);
                    const x = padding + (index * chartWidth / data.labels.length) + (datasetIndex * barWidth);
                    const y = padding + chartHeight - barHeight;
                    
                    // Format the value
                    const formattedValue = options.formatter ? 
                        options.formatter(value, { datasetIndex, index }) : 
                        value.toString();
                    
                    // Set font properties
                    ctx.fillStyle = options.color || '#000';
                    ctx.font = `${options.font?.weight || 'bold'} ${options.font?.size || 10}px ${options.font?.family || 'Arial'}`;
                    ctx.textAlign = options.align || 'center';
                    ctx.textBaseline = 'bottom';
                    
                    // Calculate position based on anchor
                    let labelX = x + (barWidth * 0.4);
                    let labelY = y - 5;
                    
                    if (options.anchor === 'end') {
                        labelY = y - 5;
                    } else if (options.anchor === 'start') {
                        labelY = y + barHeight + 15;
                    } else if (options.anchor === 'center') {
                        labelY = y + (barHeight / 2);
                    }
                    
                    // Apply offset
                    if (options.offset) {
                        labelY += options.offset;
                    }
                    
                    // Draw the label
                    ctx.fillText(formattedValue, labelX, labelY);
                });
            });
        }
    };
    
    return ChartDataLabels;
})();
