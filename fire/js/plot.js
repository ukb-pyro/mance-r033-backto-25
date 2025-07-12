// ========================================
// GLOBAL STATE MANAGEMENT
// ========================================
let currentGroup = 'both';
let donorData = null;
let controlData = null;

// ========================================
// INITIALIZATION
// ========================================
window.onload = async () => {
    try {
        // Pre-generate both datasets
        donorData = generateSurvivalData('donor');
        controlData = generateSurvivalData('control');
        
        // Load overlayed curves by default
        await loadData('both');
    } catch (error) {
        console.error('Error loading initial data:', error);
        document.getElementById('plotDiv').innerHTML = '<p style="color: red;">Error loading data. Check console for details.</p>';
    }
};

// ========================================
// MAIN DATA LOADING FUNCTION
// ========================================
async function loadData(type) {
    currentGroup = type;
    await Promise.all([loadKM(type), loadBeta(type)]);
    
    // Update button states
    document.querySelectorAll('#toggle button').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.type === type) {
            btn.classList.add('active');
        }
    });
}

// ========================================
// KAPLAN-MEIER CURVE VISUALIZATION
// ========================================
async function loadKM(type) {
    let traces = [];
    let title = '';
    
    if (type === 'both') {
        // Overlay both curves
        traces = [
            {
                x: donorData.time,
                y: donorData.survival,
                type: 'scatter',
                mode: 'lines+markers',
                name: 'Donor Survival',
                line: { color: '#00ffcc', width: 3 },
                marker: { size: 4 }
            },
            {
                x: controlData.time,
                y: controlData.survival,
                type: 'scatter',
                mode: 'lines+markers',
                name: 'Control Survival',
                line: { color: '#ff6b6b', width: 3 },
                marker: { size: 4 }
            }
        ];
        title = 'Donor vs Control Survival Comparison';
    } else if (type === 'donor') {
        traces = [{
            x: donorData.time,
            y: donorData.survival,
            type: 'scatter',
            mode: 'lines+markers',
            name: 'Donor Survival',
            line: { color: '#00ffcc', width: 3 },
            marker: { size: 6 }
        }];
        title = 'Donor Survival Curve';
    } else {
        traces = [{
            x: controlData.time,
            y: controlData.survival,
            type: 'scatter',
            mode: 'lines+markers',
            name: 'Control Survival',
            line: { color: '#ff6b6b', width: 3 },
            marker: { size: 6 }
        }];
        title = 'Control Survival Curve';
    }
    
    Plotly.newPlot('plotDiv', traces, {
        title: title,
        xaxis: { 
            title: 'Time (days)', 
            gridcolor: '#333',
            showgrid: true
        },
        yaxis: { 
            title: 'Survival Probability', 
            range: [0, 1.05], 
            gridcolor: '#333',
            showgrid: true
        },
        plot_bgcolor: '#000',
        paper_bgcolor: '#000',
        font: { color: '#fff' },
        legend: {
            x: 0.7,
            y: 0.9,
            bgcolor: 'rgba(0,0,0,0.5)',
            bordercolor: '#fff',
            borderwidth: 1
        }
    });
}

// ========================================
// SURVIVAL DATA GENERATION
// ========================================
function generateSurvivalData(type) {
    const timePoints = [];
    const survivalProbs = [];
    
    // Create time points from 0 to 1000 days
    for (let t = 0; t <= 1000; t += 25) {
        timePoints.push(t);
    }
    
    // Generate realistic survival patterns
    if (type === 'donor') {
        // Donors: Better early survival, gradual decline
        timePoints.forEach(t => {
            // Better baseline survival with slower decline
            let s = Math.exp(-t / 900) * (1 - 0.05 * (t / 1000));
            // Add some realistic variation
            s += 0.02 * Math.sin(t / 200) * Math.exp(-t / 500);
            survivalProbs.push(Math.max(0.1, Math.min(1, s)));
        });
    } else {
        // Controls: Faster decline, more variation
        timePoints.forEach(t => {
            // Faster decline with more pronounced early mortality
            let s = Math.exp(-t / 650) * (1 - 0.15 * (t / 1000));
            // Add clinical variation
            s += 0.01 * Math.cos(t / 150) * Math.exp(-t / 400);
            survivalProbs.push(Math.max(0.05, Math.min(1, s)));
        });
    }
    
    return { time: timePoints, survival: survivalProbs };
}

// ========================================
// COEFFICIENT VISUALIZATION
// ========================================
async function loadBeta(type) {
    try {
        if (type === 'both') {
            // Show both coefficient sets side by side
            await loadComparativeBeta();
        } else {
            // Show single coefficient set
            await loadSingleBeta(type);
        }
    } catch (error) {
        console.error(`Error loading ${type} data:`, error);
        document.getElementById('betaDiv').innerHTML = `<p style="color: red;">Error loading ${type} data</p>`;
    }
}

async function loadComparativeBeta() {
    try {
        // Load both datasets
        const donorResponse = await fetch('/fire/data/donor_beta_synth.csv');
        const controlResponse = await fetch('/fire/data/control_beta_synth.csv');
        
        if (!donorResponse.ok || !controlResponse.ok) {
            throw new Error('Failed to load coefficient data');
        }
        
        const donorText = await donorResponse.text();
        const controlText = await controlResponse.text();
        
        const donorRows = donorText.trim().split('\n').slice(1);
        const controlRows = controlText.trim().split('\n').slice(1);
        
        const donorCoeffs = donorRows.map(r => parseFloat(r.split(',')[0]));
        const controlCoeffs = controlRows.map(r => parseFloat(r.split(',')[0]));
        
        const x = donorCoeffs.map((_, i) => `β${i + 1}`);
        
        Plotly.newPlot('betaDiv', [
            {
                x: x,
                y: donorCoeffs,
                type: 'bar',
                name: 'Donor',
                marker: { color: '#00ffcc' },
                offsetgroup: 1
            },
            {
                x: x,
                y: controlCoeffs,
                type: 'bar',
                name: 'Control',
                marker: { color: '#ff6b6b' },
                offsetgroup: 2
            }
        ], {
            title: 'Donor vs Control Coefficients Comparison',
            plot_bgcolor: '#000',
            paper_bgcolor: '#000',
            font: { color: '#fff' },
            barmode: 'group',
            legend: {
                x: 0.7,
                y: 0.9,
                bgcolor: 'rgba(0,0,0,0.5)',
                bordercolor: '#fff',
                borderwidth: 1
            }
        });
    } catch (error) {
        console.error('Error loading comparative beta data:', error);
        document.getElementById('betaDiv').innerHTML = '<p style="color: red;">Error loading coefficient comparison</p>';
    }
}

async function loadSingleBeta(type) {
    const path = '/fire/data/' + (type === 'donor' ? 'donor_beta_synth.csv' : 'control_beta_synth.csv');
    const response = await fetch(path);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    
    const text = await response.text();
    const rows = text.trim().split('\n').slice(1);
    const y = rows.map(r => parseFloat(r.split(',')[0]));
    const x = y.map((_, i) => `β${i + 1}`);
    
    Plotly.newPlot('betaDiv', [{
        x: x,
        y: y,
        type: 'bar',
        marker: { color: type === 'donor' ? '#00ffcc' : '#ff6b6b' }
    }], {
        title: `${type.charAt(0).toUpperCase() + type.slice(1)} Coefficients`,
        plot_bgcolor: '#000',
        paper_bgcolor: '#000',
        font: { color: '#fff' }
    });
}
