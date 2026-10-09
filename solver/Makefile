# RotorDin2 — um Makefile, fontes locais e LAPACK/BLAS 3.12.1.
# Uso: make -j5 | make MODE=debug -j5 | make qualify | make help
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# 1. Programa e diretórios (relativos à raiz do projeto).
MODE ?= release
ifneq ($(MODE),release)
ifneq ($(MODE),debug)
$(error MODE deve ser release ou debug)
endif
endif
SRC := src/source
LAPACK := lapack/lapack-3.12.1
override BUILD := build/$(MODE)
SOBJ := $(BUILD)/obj/solver
LOBJ := $(BUILD)/obj/lapack
SMOD := $(BUILD)/mod/solver
LMOD := $(BUILD)/mod/lapack
TMOD := $(BUILD)/mod/tests
override TARGET := bin/rotordin2$(if $(filter debug,$(MODE)),-debug,)
CONFIG := $(BUILD)/config.stamp

# 2. GNU Fortran e flags separados: nunca promover tipos globalmente.
ifeq ($(origin FC),default)
FC := gfortran
endif
FC ?= gfortran
ifeq ($(MODE),debug)
SOLVER_FLAGS ?= -O0 -g -cpp -std=f2018 -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow
LINALG_FLAGS ?= -O0 -g -cpp -frecursive -fcheck=all -fbacktrace
else
SOLVER_FLAGS ?= -O3 -cpp -std=f2018 -ffpe-summary=none
LINALG_FLAGS ?= -O2 -cpp -frecursive
endif
CPPFLAGS ?= -D_LINUX
LDFLAGS ?=
TEST_FLAGS := -O0 -g -std=f2018 -fcheck=all -fbacktrace

# O único backend permitido é o fonte local. Overrides antigos param o build.
ifneq ($(strip $(ROTORDIN_LIBS) $(LIBS) $(LDLIBS) $(USER_OBJS) $(BLAS_LIBRARIES) $(LAPACK_LIBRARIES)),)
$(error Remova ROTORDIN_LIBS/LIBS/LDLIBS/USER_OBJS/BLAS_LIBRARIES/LAPACK_LIBRARIES: backend somente fontes)
endif
ifneq ($(strip $(LINALG_BACKEND)),)
ifneq ($(LINALG_BACKEND),source)
$(error Somente LINALG_BACKEND=source é aceito)
endif
endif
# Não executar limpeza e build como alvos paralelos da mesma invocação.
ifneq ($(filter clean distclean rebuild qualify,$(MAKECMDGOALS)),)
ifneq ($(words $(MAKECMDGOALS)),1)
$(error Execute clean/rebuild/qualify isoladamente)
endif
endif

# 3. Fontes do solver e da biblioteca; listas explícitas, sem busca recursiva.
# Acrescentar fontes exige rever os manifestos e a seção de módulos abaixo.
SOLVER_SOURCES := $(shell cat docs/build/solver-sources.lst)
LAPACK_SOURCES := $(shell cat docs/build/lapack-sources.lst)
SOLVER_OBJS := $(addprefix $(SOBJ)/,$(SOLVER_SOURCES:.f90=.o))
LAPACK_OBJS := $(addprefix $(LOBJ)/,$(addsuffix .o,$(basename $(LAPACK_SOURCES))))
ALL_OBJS := $(SOLVER_OBJS) $(LAPACK_OBJS)
SOLVER_MODULES := $(addsuffix .mod,$(shell cat docs/build/solver-modules.lst))
LAPACK_MODULES := $(addsuffix .mod,$(shell cat docs/build/lapack-modules.lst))

# 4. Grafo explícito dos módulos. A ordem de uma lista não substitui dependências.
$(SOBJ)/calccm.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/campbl.o: $(SOBJ)/rd_campbell_engine.o $(SOBJ)/rd_commons.o
$(SOBJ)/entrada.o: $(SOBJ)/rd_bearing_contract.o $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/espmod.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o $(SOBJ)/rd_modal_tracking.o $(SOBJ)/rd_textfun.o
$(SOBJ)/expgeo.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/expmat.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/flexdisk.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/foundation.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/hpgl.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/hplots.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/indsec.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/init.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_sys.o $(SOBJ)/rd_textfun.o
$(SOBJ)/linhael.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/maprig.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/matfun.o: $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/matrizes.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o $(SOBJ)/shaft_timoshenko_cowper.o
$(SOBJ)/messages.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_textfun.o
$(SOBJ)/model_audit.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/modos.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o
$(SOBJ)/parmanv.o: $(SOBJ)/rd_bearing_contract.o $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/predad.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/progress.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/rd_bearing_contract.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/rd_campbell_engine.o: $(SOBJ)/rd_campbell_families.o $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o $(SOBJ)/rd_modal_tracking.o
$(SOBJ)/rd_campbell_families.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o $(SOBJ)/rd_spectral_families.o
$(SOBJ)/rd_commons.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/rd_harmonic_response.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_response_quality.o $(SOBJ)/rd_textfun.o
$(SOBJ)/rd_modal_metrics.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/rd_modal_tracking.o: $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o
$(SOBJ)/rd_response_quality.o: $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o
$(SOBJ)/rd_spectral_families.o: $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_tracking.o
$(SOBJ)/rd_torsion_time.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/rd_textfun.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/rdfra.o: $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/resp_f.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/resp_fv.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_harmonic_response.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/resp_t.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_harmonic_response.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/rotordin.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/saidas.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_modal_metrics.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/evalf/evalf.o: $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tcmpbl.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tcouprops.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/torsion/tentrada.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tespmod.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tflextor.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/thhmat.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/torsion/thplots.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tindsec.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tmatfun.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/torsion/tmatrices.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tmodos.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tnuinteg.o: $(SOBJ)/rd_torsion_time.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tpefora.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tpefors.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tpredad.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/torsion/tprptran.o: $(SOBJ)/rd_torsion_time.o $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tresp_f.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tsaidas.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tsecdl.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/torsion/tstatic.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/torsion/tstrange.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/torsion/ttrqdiv.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o $(SOBJ)/rd_textfun.o
$(SOBJ)/transient_forcing.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/transient_input.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/transient_matrix.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/transient_newmark.o: $(SOBJ)/rd_kinds.o
$(SOBJ)/transient_output.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/transient_solver.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(SOBJ)/transient_speed.o: $(SOBJ)/rd_commons.o $(SOBJ)/rd_kinds.o
$(LOBJ)/SRC/dlartg.o: $(LOBJ)/SRC/la_constants.o
$(LOBJ)/SRC/dlassq.o: $(LOBJ)/SRC/la_constants.o $(LOBJ)/SRC/la_xisnan.o
$(LOBJ)/SRC/la_xisnan.o: $(LOBJ)/SRC/la_constants.o
$(LOBJ)/SRC/zlartg.o: $(LOBJ)/SRC/la_constants.o
$(LOBJ)/SRC/zlassq.o: $(LOBJ)/SRC/la_constants.o $(LOBJ)/SRC/la_xisnan.o

# 5. Pré-verificação e invalidação quando compilador/flags/módulos mudam.
.PHONY: all preflight verify verify-layout verify-bin FORCE test test-linalg test-runtime test-temporal
.PHONY: clean distclean rebuild qualify help
all: $(TARGET)
verify:
	@bash tests/check_sources.sh
verify-layout:
	@bash tests/check_sources.sh --layout
preflight: verify
	@command -v $(FC) >/dev/null
	@case "$$($(FC) -dumpmachine)" in *linux*) ;; *) echo 'ERRO: esta configuração foi preparada para GNU/Linux/WSL'; exit 1;; esac
	@case ' $(SOLVER_FLAGS) $(LINALG_FLAGS) $(CPPFLAGS) $(LDFLAGS) ' in \
	  *-fdefault-*|*-freal-4-real-8*|*-finteger-4-integer-8*|*-ff2c*|*-fno-underscoring*|*-fsecond-underscoring*|*-ffast-math*|*-Ofast*) \
	  echo 'ERRO: flags alteram ABI/precisão/semântica numérica'; exit 1;; esac
	@if printf '%s\n' '$(SOLVER_FLAGS) $(LINALG_FLAGS) $(LDFLAGS)' | grep -E -- '(^|[[:space:],])-l|\.a([[:space:],]|$$)|\.so([.[:space:],]|$$)|[Ll][Aa][Pp][Aa][Cc][Kk]|[Bb][Ll][Aa][Ss]|[Mm][Kk][Ll]' >/dev/null; then \
	  echo 'ERRO: biblioteca externa nas flags'; exit 1; fi

FORCE:
$(CONFIG): FORCE | preflight
	@mkdir -p "$(BUILD)" "$(SMOD)" "$(LMOD)" "$(TMOD)"
	@{ command -v $(FC); $(FC) -dumpmachine; $(FC) -dumpfullversion -dumpversion; $(FC) --version; sha256sum "$$(command -v $(FC))"; \
	   printf '%s\n' 'MODE=$(MODE)' 'SOLVER=$(SOLVER_FLAGS)' 'LINALG=$(LINALG_FLAGS)' 'CPP=$(CPPFLAGS)' 'LINK=$(LDFLAGS)'; \
	   sha256sum Makefile docs/build/*-sources.lst docs/build/*-modules.lst; \
	 } > "$@.tmp"; \
	 missing=0; \
	 for m in $(SOLVER_MODULES); do test -s "$(SMOD)/$$m" || missing=1; done; \
	 for m in $(LAPACK_MODULES); do test -s "$(LMOD)/$$m" || missing=1; done; \
	 if ! cmp -s "$@.tmp" "$@" || test "$$missing" -eq 1; then mv "$@.tmp" "$@"; else rm "$@.tmp"; fi

$(ALL_OBJS): $(CONFIG) | preflight

# 6. Quatro regras genéricas: aplicação F2018 e formatos oficiais da LAPACK.
$(SOBJ)/%.o: $(SRC)/%.f90
	@mkdir -p "$(@D)"
	@echo 'FC solver: $<'
	$(FC) $(SOLVER_FLAGS) $(CPPFLAGS) -I$(SRC) -I$(SMOD) -J$(SMOD) -c "$<" -o "$@"

$(LOBJ)/%.o: $(LAPACK)/%.f
	@mkdir -p "$(@D)"
	@echo 'FC LAPACK 3.12.1: $<'
	$(FC) $(LINALG_FLAGS) -I$(LMOD) -J$(LMOD) -c "$<" -o "$@"

$(LOBJ)/%.o: $(LAPACK)/%.f90
	@mkdir -p "$(@D)"
	@echo 'FC LAPACK 3.12.1: $<'
	$(FC) $(LINALG_FLAGS) -I$(LMOD) -J$(LMOD) -c "$<" -o "$@"

$(LOBJ)/%.o: $(LAPACK)/%.F90
	@mkdir -p "$(@D)"
	@echo 'FC LAPACK 3.12.1: $<'
	$(FC) $(LINALG_FLAGS) -I$(LMOD) -J$(LMOD) -c "$<" -o "$@"

# 7. Link somente com os objetos produzidos pelas regras acima.
$(TARGET): $(ALL_OBJS) Makefile docs/build/lapack-sources.lst docs/build/solver-sources.lst
	@mkdir -p "$(@D)"
	@echo 'Link: RotorDin2 + LAPACK/BLAS 3.12.1 integralmente local (sem legado)'
	@printf '%s\n' $(ALL_OBJS) > "$(BUILD)/link.objects"
	$(FC) $(LDFLAGS) -Wl,-Map,"$(BUILD)/link.map" -o "$@" $(ALL_OBJS)
	@echo 'Executável: $@'

# 8. Testes nativos e bancada temporal. Python é usado apenas pelos oráculos.
LINALG_TEST := $(BUILD)/tests/linalg_smoke
COMPARATOR := $(BUILD)/tests/compare_results
$(LINALG_TEST): tests/linalg_smoke.f90 $(LAPACK_OBJS) $(CONFIG)
	@mkdir -p "$(@D)" "$(TMOD)"
	$(FC) $(TEST_FLAGS) -I$(TMOD) -J$(TMOD) -o "$@" tests/linalg_smoke.f90 $(LAPACK_OBJS)
$(COMPARATOR): tests/compare_results.f90 $(CONFIG)
	@mkdir -p "$(@D)" "$(TMOD)"
	$(FC) $(TEST_FLAGS) -I$(TMOD) -J$(TMOD) -o "$@" tests/compare_results.f90
verify-bin: $(TARGET)
	@bash tests/check_binary.sh "$(TARGET)" "$(BUILD)"
test-linalg: $(LINALG_TEST)
	@"$(LINALG_TEST)" | tee "$(BUILD)/tests/linalg.stdout"
test-runtime: $(TARGET) $(COMPARATOR)
	@bash tests/run_stdio.sh "$(TARGET)" "$(COMPARATOR)" "$(BUILD)/tests/stdio"
test-temporal: $(TARGET)
	@if [[ -n "$${REV_TEMPORAL_EVIDENCE_ROOT:-}" ]]; then \
	  REV_TEMPORAL_SKIP_BUILD=1 FC="$(FC)" bash tests/reliability/rev_temporal_run.sh \
	    "$(MODE)" "$${REV_TEMPORAL_EVIDENCE_ROOT}/$(MODE)"; \
	else \
	  REV_TEMPORAL_SKIP_BUILD=1 FC="$(FC)" bash tests/reliability/rev_temporal_run.sh "$(MODE)"; \
	fi
test: verify-bin test-linalg test-runtime test-temporal

# ST41 package: shared harmonic solve and physical synchronous orbit.
HARMONIC_ORACLE := $(BUILD)/tests/st41/harmonic_oracle
HARMONIC_COMPARATOR := $(BUILD)/tests/st41/compare_harmonic
HARMONIC_TEST_OBJS := $(filter-out $(SOBJ)/rotordin.o,$(SOLVER_OBJS)) $(LAPACK_OBJS)
$(HARMONIC_ORACLE): tests/st41/harmonic_oracle.f90 $(HARMONIC_TEST_OBJS) $(CONFIG)
	@mkdir -p "$(@D)" "$(TMOD)"
	$(FC) $(TEST_FLAGS) -ffpe-trap=invalid,zero,overflow -I$(SMOD) -J$(TMOD) -o "$@" $< $(HARMONIC_TEST_OBJS)
$(HARMONIC_COMPARATOR): tests/st41/compare_harmonic.f90 $(CONFIG)
	@mkdir -p "$(@D)" "$(TMOD)"
	$(FC) $(TEST_FLAGS) -ffpe-trap=invalid,zero,overflow -J$(TMOD) -o "$@" $<
.PHONY: test-st41-harmonic
test-st41-harmonic: $(TARGET) $(HARMONIC_ORACLE) $(HARMONIC_COMPARATOR)
	@bash tests/st41/run_harmonic.sh "$(TARGET)" "$(HARMONIC_ORACLE)" "$(HARMONIC_COMPARATOR)" "$(BUILD)/tests/st41/harmonic"

# As chamadas ao mesmo Makefile impõem ordem e herdam -j, sem subárvore Release.
rebuild:
	+$(MAKE) clean
	+$(MAKE) all
qualify:
	+$(MAKE) verify verify-layout
	+$(MAKE) clean
	+$(MAKE) all
	+$(MAKE) test
	@echo 'RotorDin2 Makefile único / LAPACK 3.12.1 / testes selecionados: PASS'

# 9. Limpeza limitada aos produtos deste projeto, nunca aos fontes.
clean:
	@rm -rf -- "$(BUILD)"
	@rm -f -- "$(TARGET)"
distclean:
	@rm -rf -- build/release build/debug
	@rm -f -- bin/rotordin2 bin/rotordin2-debug
help:
	@printf '%s\n' \
	 'make [-jN]               Compilar incrementalmente (release)' \
	 'make MODE=debug [-jN]    Compilar debug em diretório separado' \
	 'make verify              Conferir manifestos e inventários' \
	 'make test [-jN]          Executar testes selecionados' \
	 'make test-temporal       Executar bancada REV-01/REV-02 (Python nos oráculos)' \
	 'make qualify [-jN]       Verificar, limpar, compilar e testar' \
	 'make clean / distclean  Remover produtos gerados' \
	 'Documentação: README.md e docs/BUILD.md'
