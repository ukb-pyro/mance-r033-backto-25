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
