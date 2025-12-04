import os
import importlib.util
import sys

SRC_DIR = os.path.join(os.path.dirname(__file__), "src")
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

# iterate over all .py files in src except ALMIGHTY.py
for fname in os.listdir(SRC_DIR):
    if fname.endswith(".py") and fname != "ALMIGHTY.py":
        module_name = fname[:-3]
        file_path = os.path.join(SRC_DIR, fname)

        # dynamically load the module
        spec = importlib.util.spec_from_file_location(module_name, file_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        # set the data folder for this module
        data_folder = os.path.join(DATA_DIR, module_name)
        if hasattr(module, "main"):
            module.main(data_folder)
