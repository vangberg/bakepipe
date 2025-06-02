# bakepipe

bakepipe is just enough pipeline for your R scripts. It keeps track of which files depend on which other files, so you don't have to. Works great with scripts that read and write files to disk.

## Quickstart

Let's say you have a raw dataset in `data.csv` that you want to analyze and visualize. You can split this into two scripts: `analysis.r` processes the raw data and saves results to `analysis.csv`, while `plots.r` creates visualizations from those results, saving them as `plot1.png` and `plot2.png`.

Here's how these scripts would look:

```r
# analysis.r

library(bakepipe)

data <- read.csv(file_in("data.csv"))
stats <- table(data)
write.csv(stats, file_out("analysis.csv"))
```

```r
# plots.r

library(bakepipe)
library(ggplot2)

data <- read.csv(file_in("analysis.csv"))
ggplot(data, aes(x = variable, y = value)) + geom_point()
ggsave(file_out("plot1.png"))
ggsave(file_out("plot2.png"))
```

The magic happens through `file_in` and `file_out` functions. These don't actually read or write files - they just mark dependencies so bakepipe can figure out what needs to run when. When you're ready to run your pipeline, simply call:

```r
bakepipe::run()
```

This will execute your scripts in the right order and tell you which files were created.


## API

### Mark input

To mark a file as input, use `bakepipe::file_in("path/to/file")`. `file_in(path)`
returns `path`, so it can be used when reading the file:

```r
data <- read.csv(bakepipe::file_in("data.csv"))
```

### Mark output

To mark a file as output, use `bakepipe::file_out("path/to/file")`. `file_out(path)`
returns `path`, so it can be used when writing the file:

```r
write.csv(data, bakepipe::file_out("data.csv"))
```

### Show pipeline

To show the pipeline, use `bakepipe::show()`. This will show the dependencies
between the files.

```r
bakepipe::show()
```

### Run pipeline

To run the pipeline, use `bakepipe::run()`. This will run the pipeline, and
return a list of the files that were created.

```r
bakepipe::run()
```