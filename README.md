# Bakepipe

Bakepipe is a just-good-enough pipeline library for R. It embraces script based workflows, where each script is a self-contained unit that can be run independently, sharing intermediate results through files stored on disk.

## Walkthrough

### The problem

Let's say you have a raw dataset in `data.csv` that you want to analyze and visualize. You can split this into two scripts: `analysis.R` processes the raw data and saves results to `analysis.csv`, while `plots.R` creates visualizations from those results, saving them as `plot1.png` and `plot2.png`.

Now, you need to run the scripts in the right order. You can do this manually, but it's easy to forget or mess up. This is where Bakepipe comes in, by keeping track of the dependencies between the scripts and running them in the right order.

### The solution

Here's how these scripts would look:

```r
# analysis.R

library(bakepipe)

data <- read.csv(file_in("data.csv"))
stats <- table(data)
write.csv(stats, file_out("analysis.csv"))
```

```r
# plots.R

library(bakepipe)
library(ggplot2)

data <- read.csv(file_in("analysis.csv"))
ggplot(data, aes(x = variable, y = value)) + geom_point()
ggsave(file_out("plot1.png"))
ggsave(file_out("plot2.png"))
```

`file_in` and `file_out` are used to mark the input and output of the script. They both return the path to the file, so they can be used when reading or writing the file. They don't actually read or write files - they just mark dependencies so Bakepipe can figure out what needs to run when.

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

### Run pipeline

To run the pipeline, use `bakepipe::run()`. This will run the pipeline, and
return a list of the files that were created.

```r
bakepipe::run()
```

### Show pipeline

To show the pipeline, use `bakepipe::show()`. This will show the dependencies
between the files.

```r
bakepipe::show()
```

## Compared with …

I want to preface this comparison by saying that Bakepipe is much more limited in scope than other pipeline tools. It's not a replacement for tools like Snakemake or Nextflow, but rather a tool for simple workflows that don't need the complexity of those tools. Yet, I want to highlight some of the features that make Bakepipe unique.

### Snakemake

With Snakemake, you would define the workflow from the walkthrough above as follows:

```yaml
rule all: 
    input: "plot1.png", "plot2.png"

rule analysis:
    input: "data.csv"
    output: "analysis.csv"
    shell: "Rscript analysis.R"

rule plots:
    input: "analysis.csv"
    output: "plot1.png", "plot2.png"
    shell: "Rscript plots.R"
```

And to run the pipeline, you would use the following command:

```bash
snakemake
```

Compared with Bakepipe, I think this adds friction. You need to do double bookkeeping, manually keeping the Snakefile and the scripts in sync.

### targets

To implement the same workflow in targets, you would need to refactor the scripts into functions, and then use the `tar_target` function to define the targets.

```r
# functions.R

get_data <- function(file) {
    read.csv(file)
}

analyze <- function(data) {
    table(data)
}

plot1 <- function(data) {
    plot <- ggplot(data, aes(x = variable, y = value)) + geom_point()
    ggsave("plot1.png", plot)
}

plot2 <- function(data) {
    ggplot(data, aes(x = variable, y = value)) + geom_point()
    ggsave("plot2.png")
}
```

```r
# _targets.R

library(targets)

tar_source()

list(
    tar_target(file, "data.csv", format = "file"),
    tar_target(data, get_data(file)),
    tar_target(analysis, analyze(data)),
    tar_target(plot1, plot1(analysis)),
    tar_target(plot2, plot2(analysis)),
)
```

In other words, to use targets, you need to abandon your script based workflow, and start writing functions. This in itself is not really a big change, worst case you could just wrap each script in a function. But in the process, you lose some of the advantages of a script based workflow, namely the iterative and interactive development.