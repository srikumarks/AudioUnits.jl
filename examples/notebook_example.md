# Jupyter Notebook Display Examples

This document shows how AudioUnits.jl objects are displayed in Jupyter notebooks with rich HTML formatting.

## Setup

First, ensure you have IJulia installed:

```julia
using Pkg
Pkg.add("IJulia")
```

Then start a Jupyter notebook:

```julia
using IJulia
notebook()
```

## Example Notebook Cells

### Cell 1: Load the package and find AudioUnits

```julia
using AudioUnits

# Find all effects
effects = find_audiounits(kAudioUnitType_Effect)
println("Found $(length(effects)) effect(s)")

# Find all instruments
instruments = find_audiounits(kAudioUnitType_MusicDevice)
println("Found $(length(instruments)) instrument(s)")
```

### Cell 2: Load and display an AudioUnit

```julia
# Load an effect AudioUnit (adjust name as needed)
au = load_audiounit("AULowpass")

# Display it - will automatically use HTML rendering in Jupyter
display(au)
```

This will show a beautifully formatted display with:
- AudioUnit name with status badge (Initialized/Uninitialized)
- Basic information (manufacturer, type, version)
- Capabilities with checkmarks (✓/✗)
- Channel configurations in pill-style badges
- Performance metrics (latency, tail time) if initialized
- Parameters in a scrollable table

### Cell 3: Initialize and display again

```julia
# Initialize the AudioUnit
initialize_audiounit(au)

# Display again to see performance metrics
display(au)
```

After initialization, you'll see additional performance information like latency and tail time.

### Cell 4: Display individual parameters

```julia
# Get all parameters
params = get_parameters(au)

# Display the first parameter
if !isempty(params)
    display(params[1])
end
```

This shows a parameter with:
- Parameter ID, scope, and element
- Name (highlighted)
- Value range and default
- Unit type

### Cell 5: Display parameter info

```julia
# Get parameter info for detailed view
if !isempty(params)
    info = params[1].info
    display(info)
end
```

### Cell 6: Compare multiple AudioUnits

```julia
# Load and compare different AudioUnits
units_to_compare = ["AULowpass", "AUHighpass", "AUBandpass"]

for unit_name in units_to_compare
    try
        au = load_audiounit(unit_name)
        initialize_audiounit(au)
        display(au)
        uninitialize_audiounit(au)
        dispose_audiounit(au)
    catch e
        println("Could not load $unit_name: $e")
    end
end
```

### Cell 7: Explore parameters interactively

```julia
au = load_audiounit("AULowpass")
initialize_audiounit(au)

params = get_parameters(au)

println("Parameters for $(au.name):")
for (i, param) in enumerate(params)
    println("\n[$i]")
    display(param)
end

uninitialize_audiounit(au)
dispose_audiounit(au)
```

## Display Features

### AudioUnit Display (HTML)

The HTML display includes:

1. **Header Section**
   - AudioUnit name with music note emoji
   - Status badge (green for initialized, orange for uninitialized)

2. **Two-Column Layout**
   - Left: Basic information (manufacturer, type, subtype, version)
   - Right: Capabilities with color-coded checkmarks

3. **Channel Configurations**
   - Displayed as blue pill-style badges
   - Shows input → output channel counts

4. **Performance Metrics** (when initialized)
   - Latency in milliseconds
   - Tail time in seconds

5. **Parameters Table**
   - Scrollable table with sticky header
   - Shows name, range, default, and unit for each parameter
   - Limited height with overflow scrolling

### Parameter Display (HTML)

- Green-themed bordered box
- Table layout with parameter details
- Parameter name is bolded
- ID, scope, element, range, default, and unit shown

### Parameter Info Display (HTML)

- Simple gray-themed box
- Focused on just the parameter information
- Name, unit, range, and default value

## Tips for Notebook Usage

1. **Automatic HTML Rendering**: Just use `display(object)` or have the object as the last expression in a cell

2. **Explicit MIME Type**: Force a specific display format:
   ```julia
   show(stdout, MIME("text/html"), au)
   ```

3. **Plain Text in Notebook**: If you prefer plain text even in Jupyter:
   ```julia
   show(stdout, MIME("text/plain"), au)
   ```

4. **Combine with Plots**: Display AudioUnit info alongside audio processing visualizations

5. **Interactive Exploration**: Use the display methods to explore available AudioUnits and their parameters before integrating them into your audio pipeline

## Styling

The HTML displays use:
- Clean, modern design with rounded corners
- Color-coded status indicators
- Responsive tables
- Professional typography
- Scrollable sections for long parameter lists
- Grid layouts for organized information presentation

All styling is inline CSS, so it works in any Jupyter environment without additional setup.
