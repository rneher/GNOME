rule all:
    input:
        auspice_tree = "auspice/GNOME_tree.json",
        auspice_meta = "auspice/GNOME_meta.json"

input_fasta = "../cleaned_sequences.fasta",
input_alignment = "../alignment.fasta",
metadata = "../2019-02_alignments/ARF-GEFs_species-list_15Feb19.csv",
dropped_strains = "config/dropped_strains.txt",
colors = "config/colors.tsv",
auspice_config = "config/auspice_config.json"


rule align:
    message:
        """
        Aligning sequences to {input.reference}
          - filling gaps with N
        """
    input:
        sequences = input_fasta
    output:
        alignment = "results/aligned.fasta"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --output {output.alignment}
        """

rule tree:
    message: "Building tree"
    input:
        alignment = input_alignment
    output:
        tree = "results/tree_raw.nwk"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
             -m JTT+R5
        """

rule refine:
    message:
        """
        Refining tree
        """
    input:
        # tree = rules.tree.output.tree,
        tree = "../alignment.fasta.treefile",
        alignment = input_alignment,
        metadata = metadata
    output:
        tree = "results/tree.nwk",
        node_data = "results/branch_lengths.json"
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} --aa \
            --metadata {input.metadata} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data}
        """

rule ancestral:
    message: "Reconstructing ancestral sequences and mutations"
    input:
        tree = rules.refine.output.tree,
        alignment = input_alignment
    output:
        node_data = "results/aa_muts.json"
    params:
        inference = "joint"
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} --aa \
            --output {output.node_data} \
            --inference {params.inference}
        """


rule export:
    message: "Exporting data files for for auspice"
    input:
        tree = rules.refine.output.tree,
        metadata = metadata,
        branch_lengths = rules.refine.output.node_data,
        aa_muts = rules.ancestral.output.node_data,
        colors = colors,
        auspice_config = auspice_config
    output:
        auspice_tree = rules.all.input.auspice_tree,
        auspice_meta = rules.all.input.auspice_meta
    shell:
        """
        augur export \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.aa_muts} \
            --colors {input.colors} \
            --auspice-config {input.auspice_config} \
            --output-tree {output.auspice_tree} \
            --output-meta {output.auspice_meta}
        """

rule clean:
    message: "Removing directories: {params}"
    params:
        "data "
        "results ",
        "auspice"
    shell:
        "rm -rfv {params}"
