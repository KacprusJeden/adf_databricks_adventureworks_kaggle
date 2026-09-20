# adf_databricks_adventureworks_kaggle

Pipeline danych oparty o **Azure Data Factory** (orkiestracja) i **Azure Databricks** (transformacje), przetwarzający dane AdventureWorks pobrane z **Kaggle** przez warstwy Bronze → Silver → Gold (medallion architecture).

> ⚠️ To repo zawiera wyłącznie definicje zasobów ADF (JSON) oraz notebooki Databricks — **nie zawiera żadnych sekretów/poświadczeń**. Żeby projekt zadziałał, musisz postawić własną infrastrukturę Azure i podmienić referencje wskazane w sekcji [Co trzeba podmienić](#co-trzeba-podmienić).

## Spis treści
- [Architektura](#architektura)
- [Struktura repozytorium](#struktura-repozytorium)
- [Wymagana infrastruktura](#wymagana-infrastruktura)
- [Setup krok po kroku](#setup-krok-po-kroku)
- [Co trzeba podmienić](#co-trzeba-podmienić)
- [Podmiana ścieżek notebookowych w Databricks](#podmiana-ścieżek-notebookowych-w-databricks)
- [Znane pułapki](#znane-pułapki)

## Architektura

```
Kaggle (dataset AdventureWorks)
        │  (ADF: HTTP/Kaggle linked service + Copy activity)
        ▼
   ADLS Gen2 / Storage — warstwa BRONZE (surowe dane)
        │  (ADF: Notebook Activity → Databricks)
        ▼
   Databricks notebook — warstwa SILVER (czyszczenie, transformacje)
        │
        ▼
   Databricks notebook — warstwa GOLD (modelowanie, agregacje)
        │
        ▼
   (opcjonalnie: Synapse / Power BI — warstwa serwująca)
```

Orkiestracją całości zajmuje się pipeline ADF, który po kolei woła Copy Activity (pobranie danych) i Notebook Activity (uruchomienie transformacji na klastrze Databricks).

## Struktura repozytorium

To standardowy układ repo zintegrowanego z ADF przez **Git configuration** (Manage → Git configuration w ADF Studio) — ADF sam publikuje/synchronizuje te foldery:

| Folder/plik | Zawartość |
|---|---|
| `factory/` | definicja samej Data Factory (ustawienia globalne) |
| `linkedService/` | połączenia do zewnętrznych usług (Databricks, storage, źródło Kaggle/HTTP) — **tu żyją referencje do credentiali** |
| `dataset/` | definicje zbiorów danych (ścieżki, kontenery, formaty plików) używane przez pipeline'y |
| `pipeline/` | definicje samych pipeline'ów (kolejność aktywności, zależności) |
| `notebooks/` | notebooki Databricks wywoływane przez Notebook Activity |
| `publish_config.json` | konfiguracja publikacji ADF (nazwa factory, subskrypcja, resource group) |
| `adf-kacprusjeden-swec-001/` | *(prawdopodobnie eksport ARM template tej instancji ADF — do weryfikacji, czy jest nadal potrzebny w repo, czy to zbędny artefakt)* |

## Wymagana infrastruktura

Żeby ten projekt miał rację bytu, musisz postawić w Azure (nazwy poniżej to **propozycja konwencji nazewniczej** — możesz użyć swojej, ale bądź konsekwentny):

| Zasób | Przykładowa nazwa | Do czego służy |
|---|---|---|
| Resource Group | `rg-adf-aw-kaggle-<region>` | kontener na wszystkie zasoby projektu |
| Azure Data Factory | `adf-<twoj-alias>-<region>-001` (u autora: `adf-kacprusjeden-swec-001`) | orkiestracja pipeline'u |
| Storage Account (ADLS Gen2) | `stadfawkaggle<region>001` | warstwy Bronze/Silver/Gold |
| Azure Databricks Workspace | `dbw-adf-aw-kaggle-<region>-001` | uruchamianie notebooków transformacyjnych |
| Databricks — cluster (single node wystarczy) | np. `standard_d4ds_v5` | compute pod notebooki |
| Konto/token Kaggle | — | pobranie datasetu AdventureWorks przez Kaggle API |
| *(opcjonalnie)* Azure Key Vault | `kv-adf-aw-kaggle-001` | bezpieczne przechowywanie tokenów/kluczy zamiast wpisywania ich wprost w linked service |

## Setup krok po kroku

1. **Utwórz Resource Group** i wszystkie zasoby z tabeli wyżej.
2. **Sklonuj to repo** lokalnie lub podepnij bezpośrednio jako Git configuration nowej instancji ADF (Manage → Git configuration → wskaż to repo/branch `main`).
3. **Skonfiguruj Linked Services** (`linkedService/*.json`) — zobacz sekcję niżej, co dokładnie podmienić.
4. **Zaktualizuj Datasets** (`dataset/*.json`) — nazwy kontenerów/ścieżek storage, jeśli różnią się od Twoich.
5. **Wgraj notebooki z `notebooks/`** do swojego Databricks workspace (przez Databricks CLI, `databricks workspace import`, albo przez Git folder w samym Databricksie).
6. **Podmień ścieżki notebookowe w pipeline** — patrz sekcja niżej.
7. **Publish** w ADF Studio (albo `Publish` przez Git jeśli masz ustawiony branch `adf_publish`).
8. **Uruchom pipeline ręcznie (Debug/Trigger now)** i zweryfikuj każdą warstwę (Bronze → Silver → Gold) osobno, zanim ustawisz harmonogram.

## Co trzeba podmienić

To jest kluczowa lista — bez tego pipeline nie zadziała na Twoim koncie, nawet jeśli struktura się zgadza:

- **`linkedService/` — Databricks Linked Service**
  - `existingClusterId` lub konfiguracja `newClusterOptions` → Twój cluster ID (lub definicja nowego klastra)
  - URL workspace'u Databricks (`domain`) → Twój adres `adb-<id>.<region>.azuredatabricks.net`
  - token dostępowy → **nie wpisuj wprost do JSON-a** jeśli planujesz to publikować (jak robisz teraz) — użyj referencji do Azure Key Vault albo Managed Identity ADF z uprawnieniem odpowiadającym roli na workspace Databricks

- **`linkedService/` — Storage / ADLS Linked Service**
  - nazwa storage account
  - connection string / referencja do Key Vault z kluczem dostępu (albo Managed Identity, jeśli masz nadane uprawnienia RBAC na storage)

- **`linkedService/` — Kaggle/HTTP Linked Service** (jeśli pobieranie idzie przez HTTP/API, nie ręczny upload)
  - base URL API
  - klucz/token Kaggle (Kaggle wymaga `username` + `key` z pliku `kaggle.json` — te wartości muszą trafić do Key Vault lub parametrów pipeline'u, nigdy na sztywno do repo)

- **`dataset/*.json`**
  - nazwy kontenerów (`bronze`, `silver`, `gold` — albo Twoja konwencja)
  - ścieżki/foldery wewnątrz storage, jeśli różnią się od oryginalnych

- **`publish_config.json`**
  - nazwa Data Factory, subskrypcja, resource group — muszą wskazywać na Twoją instancję ADF, nie na oryginalną autora

## Podmiana ścieżek notebookowych w Databricks

To jest krok, o który pytałeś, i jest tu istotny problem strukturalny, o którym warto wiedzieć zanim zaczniesz:

- Notebook Activity w `pipeline/*.json` wskazuje na **konkretną, sztywno wpisaną ścieżkę** notebooka w Databricks Workspace, np. `/Workspace/Repos/<uzytkownik>/<repo>/notebooks/gold`.
- Ta ścieżka **zależy od tego, kto i gdzie sklonował repo w Databricksie** — jeśli sklonujesz je pod swoim kontem, Twoja ścieżka będzie inna niż w oryginalnym pipeline.
- **Co zrobić:** w każdej aktywności Notebook Activity w plikach `pipeline/*.json` znajdź pole `"notebookPath"` i podmień je na ścieżkę odpowiadającą **Twojemu** checkoutowi repo w Databricks Workspace (np. `/Workspace/Repos/<twoj-email>/adf_databricks_adventureworks_kaggle/notebooks/gold`).
- **Rekomendacja (nie wymóg na start, ale wart rozważenia):** zamiast wskazywać na osobisty checkout, warto docelowo skierować to na dedykowany checkout tożsamości service principal/managed identity, z którą łączy się ADF — dzięki temu ścieżka nie zależy od tego, kto akurat ma sklonowane repo lokalnie i na jakim jest branchu. To nie jest konieczne, żeby projekt ruszył, ale zapobiega sytuacji, w której pipeline się wysypuje, bo ktoś przełączył branch w swoim własnym Git folderze.

## Znane pułapki

- **Unity Catalog / allowlisty w Databricks** — jeśli Twój workspace ma włączone restrykcje governance (artifact allowlist na init scripty, Git URL allowlist dla Azure DevOps/innych providerów), pierwsze uruchomienie może wymagać dodatkowej konfiguracji po stronie admina workspace'u, zanim cokolwiek się połączy.
- **Token Kaggle** — pamiętaj, że token API Kaggle bywa powiązany z limitem requestów; przy testowaniu pipeline'u w pętli możesz go wyczerpać.
- **Klaster single-node** — wystarczy do notebooków transformacyjnych w tej skali danych, ale pamiętaj o ustawieniu auto-terminate, żeby nie płacić za bezczynny compute między uruchomieniami.

---

*Uwaga: ta wersja README została przygotowana na podstawie widocznej struktury folderów repo — nie miałem dostępu do dokładnej zawartości plików `linkedService/*.json`/`dataset/*.json`. Jeśli wkleisz mi ich zawartość (bez wartości sekretów), doprecyzuję sekcję "Co trzeba podmienić" do stanu w 100% zgodnego z Twoją konfiguracją.*
