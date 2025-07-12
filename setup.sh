#!/bin/bash

# ========================================
# UKUBONA RECURSIVE SETUP ENGINE
# ========================================

set -e  # Exit on any error
set -u  # Exit on undefined variables

DEFAULT_USER="ukb-pyro"
DEFAULT_PORT=5001
echo "🌐 Ukubona Recursive Setup Engine"

# ========================================
# USER INPUT COLLECTION & VALIDATION
# ========================================

# GitHub username
read -p "GitHub username [$DEFAULT_USER]: " GH_USER
GH_USER=${GH_USER:-$DEFAULT_USER}

# Repository name
read -p "Repo name (to scaffold interactive engine): " GH_REPO
if [[ -z "$GH_REPO" ]]; then
  echo "❌ Repository name is required"
  exit 1
fi

# Personal access token (hidden input)
read -s -p "PERSONAL_ACCESS_TOKEN: " GH_TOKEN
echo  # New line after hidden input
if [[ -z "$GH_TOKEN" ]]; then
  echo "❌ Personal access token is required"
  exit 1
fi

# Branch name validation
read -p "Branch name (not 'main'): " GH_BRANCH
if [[ -z "$GH_BRANCH" ]]; then
  echo "❌ Branch name is required"
  exit 1
fi

# Port configuration
read -p "Port to run Flask on [$DEFAULT_PORT]: " PORT
PORT=${PORT:-$DEFAULT_PORT}

# ========================================
# INPUT VALIDATION
# ========================================

# Validate branch name
if [[ "$GH_BRANCH" == "main" || ! "$GH_BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  echo "❌ Invalid branch: $GH_BRANCH (cannot be 'main' and must contain only alphanumeric, dots, underscores, hyphens, or slashes)"
  exit 1
fi

# Validate port range
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
  echo "❌ Invalid port: $PORT (must be between 1024-65535)"
  exit 1
fi

# ========================================
# PROJECT DIRECTORY SETUP
# ========================================

echo "📁 Creating project directory: $GH_REPO"
mkdir -p "$GH_REPO" && cd "$GH_REPO"

# ========================================
# PYTHON DATA GENERATION SCRIPT
# ========================================

echo "📝 Creating origins.py..."
cat << 'EOF' > origins.py
import os
import pandas as pd
import numpy as np
from lifelines import KaplanMeierFitter

print("🔧 Setting up data directories...")
os.makedirs("fire/data", exist_ok=True)

src = "https://raw.githubusercontent.com/abikesa/gtpci-forum/main/kitabo/ensi/testbin/test2/assets/csv"
csv_files = ["survival.csv", "donor_coef.csv", "donor_cov.csv", "control_coef.csv", "control_cov.csv"]

print("📥 Downloading CSV files...")
for fname in csv_files:
    url = f"{src}/{fname}"
    try:
        df = pd.read_csv(url)
        df.to_csv(f"fire/data/{fname}", index=False)
        print(f"✅ Downloaded {fname}")
    except Exception as e:
        print(f"⚠️ Can't download {fname}: {e}")
        print("   Generating synthetic data instead...")

# Synthetic fallback data
print("🎲 Generating synthetic data...")
np.random.seed(42)

# Survival data
duration = np.random.exponential(365, 200)
event = np.random.binomial(1, 0.7, 200)
kmf = KaplanMeierFitter().fit(duration, event)
kmf_df = kmf.survival_function_.reset_index()
kmf_df.columns = ["time", "KM"]
kmf_df.to_csv("fire/data/km_synth.csv", index=False)

# Coefficient data
donor_beta = np.array([0.5, -0.3, 0.2])
nondonor_beta = np.array([-0.1, 0.4, -0.2])
pd.DataFrame(donor_beta, columns=['coefficient']).to_csv("fire/data/donor_beta_synth.csv", index=False)
pd.DataFrame(nondonor_beta, columns=['coefficient']).to_csv("fire/data/control_beta_synth.csv", index=False)

print("✅ Data preparation complete!")
EOF

# ========================================
# HTML TEMPLATE CREATION
# ========================================

echo "📝 Creating index.html..."
cat << 'EOF' > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KM + Coeff Models</title>
    <link href="/fire/css/style.css" rel="stylesheet">
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>
    <h1>Kaplan–Meier + Donor vs Control Model</h1>
    <div id="plotDiv"></div>
    <div id="toggle">
        <button data-type="both" onclick="loadData('both')">Both Curves</button>
        <button data-type="donor" onclick="loadData('donor')">Donor Only</button>
        <button data-type="control" onclick="loadData('control')">Control Only</button>
    </div>
    <div id="betaDiv"></div>
    <script src="/fire/js/plot.js"></script>
</body>
</html>
EOF

# ========================================
# FRONTEND ASSET CREATION
# ========================================

echo "📁 Creating asset directories..."
mkdir -p fire/js fire/css

# ========================================
# INTERACTIVE JAVASCRIPT IMPLEMENTATION
# ========================================

echo "📝 Creating plot.js..."
cat << 'EOF' > fire/js/plot.js
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
EOF

# ========================================
# CSS STYLING IMPLEMENTATION
# ========================================

echo "📝 Creating style.css..."
cat << 'EOF' > fire/css/style.css
body {
    background: #000;
    color: #fff;
    font-family: Arial, sans-serif;
    text-align: center;
    margin: 0;
    padding: 20px;
}

h1 {
    margin: 20px 0;
    font-size: 2em;
}

#plotDiv, #betaDiv {
    width: 80%;
    margin: 30px auto;
    height: 400px;
    border: 1px solid #333;
    border-radius: 8px;
}

#toggle {
    margin: 20px 0;
}

button {
    margin: 0 5px;
    padding: 8px 16px;
    font-size: 14px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    background: #333;
    color: #fff;
    transition: background 0.3s;
    min-width: 100px;
}

button.active {
    background: #007acc;
    color: #fff;
}

button:hover {
    background: #555;
}

button:active {
    background: #222;
}
EOF

# ========================================
# FLASK WEB APPLICATION SETUP
# ========================================

echo "📝 Creating app.py..."
cat << EOF > app.py
from flask import Flask, send_from_directory
import sys
import os

# Get port from environment variable or command line or use default
PORT = int(os.getenv('PORT', sys.argv[1] if len(sys.argv) > 1 else $PORT))
app = Flask(__name__, static_folder='.')

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/<path:path>')
def static_proxy(path):
    # Security check to prevent directory traversal
    if '..' in path or path.startswith('/'):
        return "Access denied", 403
    return send_from_directory('.', path)

if __name__ == '__main__':
    print(f"🚀 Starting Flask server on port {PORT}")
    app.run(debug=True, port=PORT, host='0.0.0.0')
EOF

# ========================================
# PYTHON DEPENDENCIES SPECIFICATION
# ========================================

echo "📝 Creating requirements.txt..."
cat << 'EOF' > requirements.txt
Flask>=2.0.0
lifelines>=0.27.0
pandas>=1.3.0
numpy>=1.21.0
gunicorn>=20.1.0
EOF

# ========================================
# RENDER.YAML CONFIGURATION
# ========================================

echo "�� Creating render.yaml..."
cat << EOF > render.yaml
services:
  - type: web
    name: $GH_REPO
    env: python
    plan: free
    region: oregon
    buildCommand: |
      python3 -m venv venv
      source venv/bin/activate
      pip install --upgrade pip
      pip install -r requirements.txt
      python3 origins.py
    startCommand: gunicorn app:app
    envVars:
      - key: PYTHON_VERSION
        value: 3.9
      - key: FLASK_ENV
        value: production
EOF

# ========================================
# FLASK SERVER CLEANUP & PYTHON SETUP
# ========================================

# Kill any existing Flask servers to prevent port conflicts
echo "🧹 Cleaning up existing Flask servers..."
FLASK_PROCESSES=$(ps aux | grep "[p]ython.*app.py" | awk '{print $2}' || true)
if [ -n "$FLASK_PROCESSES" ]; then
    echo "🔄 Found existing Flask processes, terminating..."
    echo "$FLASK_PROCESSES" | xargs kill -9 2>/dev/null || true
    sleep 1
    echo "✅ Cleanup complete"
else
    echo "ℹ️ No existing Flask processes found"
fi

# Check if port is in use and kill processes using it
echo "🔍 Checking if port $PORT is in use..."
PORT_PID=$(lsof -ti:$PORT 2>/dev/null || true)
if [ -n "$PORT_PID" ]; then
    echo "⚠️ Port $PORT is in use by PID: $PORT_PID"
    echo "🔄 Terminating processes on port $PORT..."
    kill -9 $PORT_PID 2>/dev/null || true
    sleep 1
    echo "✅ Port $PORT is now free"
fi

# ========================================
# PYTHON ENVIRONMENT SETUP
# ========================================

echo "🐍 Setting up Python environment..."

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed or not in PATH"
    exit 1
fi

# Remove existing virtual environment if it exists
if [ -d "fire/myenv" ]; then
    echo "🗑️ Removing existing virtual environment..."
    rm -rf fire/myenv
fi

# Create fresh virtual environment
echo "📦 Creating new virtual environment..."
python3 -m venv fire/myenv
if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    exit 1
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source fire/myenv/bin/activate
if [ $? -ne 0 ]; then
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

# Install packages
echo "📥 Installing Python packages..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
if [ $? -ne 0 ]; then
    echo "❌ Failed to install Python packages"
    exit 1
fi

# Run data setup
echo "🔧 Running data setup..."
python3 origins.py
if [ $? -ne 0 ]; then
    echo "❌ Failed to run data setup"
    exit 1
fi

# ========================================
# FLASK SERVER LAUNCH
# ========================================

echo "🚀 Starting Flask server on port $PORT..."
nohup python3 app.py $PORT > flask.log 2>&1 &
FLASK_PID=$!
echo "📋 Flask server started with PID: $FLASK_PID"

# Wait for server to initialize
echo "⏳ Waiting for server to initialize..."
sleep 3

# Verify Flask is running
if ps -p $FLASK_PID > /dev/null; then
    echo "✅ Flask server is running successfully"
    
    # Test if server is responding
    if curl -s http://127.0.0.1:$PORT >/dev/null 2>&1; then
        echo "🌐 Server is responding to HTTP requests"
    else
        echo "⚠️ Server started but may not be responding yet"
    fi
else
    echo "❌ Flask server failed to start. Check flask.log for details:"
    echo "--- START OF FLASK LOG ---"
    cat flask.log 2>/dev/null || echo "No log file found"
    echo "--- END OF FLASK LOG ---"
    exit 1
fi

# ========================================
# GIT REPOSITORY INITIALIZATION
# ========================================

echo "🔄 Initializing Git repository..."

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed or not in PATH"
    exit 1
fi

# Initialize git repository
git init
git checkout -b "$GH_BRANCH"
git add .
git commit -m "🌊 Auto-bootstrap KM engine with synth + toggle UX"

# ========================================
# GITHUB REMOTE SETUP & PUSH
# ========================================

echo "🚀 Pushing to GitHub..."
git remote add origin https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git
git push -u origin "$GH_BRANCH"

# ========================================
# FINAL SUCCESS SUMMARY
# ========================================

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 ===== SETUP COMPLETE ===== 🎉"
    echo "✅ Successfully pushed to GitHub!"
    echo "🔗 Repository: https://github.com/${GH_USER}/${GH_REPO}"
    echo "🌐 Local UI: http://127.0.0.1:$PORT"
    echo "📋 Flask PID: $FLASK_PID (use 'kill $FLASK_PID' to stop)"
    echo "📝 Logs: Check flask.log for server output"
    echo "🔧 Virtual env: fire/myenv (activated)"
    echo "📦 Ready for Render.com: Deploy using render.yaml"
    echo "======================================="
else
    echo "❌ Failed to push to GitHub. Check your credentials and repository settings."
    exit 1
fi
