process STIMULUS_SPLIT_DATA {

    tag "${meta.id}-${meta2.id}"
    label 'process_low'
    // TODO: push image to nf-core quay.io
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(data)
    tuple val(meta2), path(sub_config)

    output:
    tuple val(meta2), path("${prefix}.csv"), emit: csv_with_split
    path "versions.yml"          , emit: versions

    script:
    prefix = task.ext.prefix ?: "${meta.id}-split-${meta2.id}"
    """
    stimulus split-csv \
        -c ${data} \
        -y ${sub_config} \
        -o ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}-split-${meta2.id}"
    """
    touch ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
