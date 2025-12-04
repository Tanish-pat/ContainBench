import os
import matplotlib.pyplot as plt

def parse_log_file(file_path):
    sizes = []
    used = []
    avail = []
    with open(file_path) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 6 and parts[0].startswith("/dev"):
                sizes.append(convert_to_gb(parts[1]))
                used.append(convert_to_gb(parts[2]))
                avail.append(convert_to_gb(parts[3]))
    return sizes, used, avail

def convert_to_gb(val):
    # convert size like 1.6G, 491G to float GB
    if val.endswith("G"):
        return float(val[:-1])
    elif val.endswith("M"):
        return float(val[:-1])/1024
    else:
        return float(val)

def main(data_folder):
    if not os.path.exists(data_folder):
        print(f"No data folder: {data_folder}")
        return

    log_files = sorted([f for f in os.listdir(data_folder) if f.endswith(".log")])
    all_used = []
    all_avail = []

    for log_file in log_files:
        path = os.path.join(data_folder, log_file)
        sizes, used, avail = parse_log_file(path)
        all_used.append(sum(used))
        all_avail.append(sum(avail))

    # create plots
    plt.figure(figsize=(10,5))
    plt.plot(all_used, label="Used Space (GB)")
    plt.plot(all_avail, label="Available Space (GB)")
    plt.title(os.path.basename(data_folder))
    plt.xlabel("Log File Index")
    plt.ylabel("GB")
    plt.legend()

    plots_dir = os.path.join(data_folder, "plots")
    os.makedirs(plots_dir, exist_ok=True)
    plt.savefig(os.path.join(plots_dir, "usage_plot.png"))
    plt.close()
    print(f"Plot saved to {os.path.join(plots_dir, 'usage_plot.png')}")