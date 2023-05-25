export PATH := $(HOME)/.local/bin:$(PATH)

all: venv/adsbs/bin/adsbs
	@. venv/adsbs/bin/activate; adsbs -r

venv/adsbs/bin/adsbs: venv/adsbs
	@. venv/adsbs/bin/activate; pip install -e .

venv/adsbs: venv/virtualenv.stamp
	@virtualenv -p python3 venv/adsbs

venv/virtualenv.stamp:
	@install -d venv
	@command -v virtualenv >/dev/null || pip3 install --user virtualenv
	@touch venv/virtualenv.stamp
