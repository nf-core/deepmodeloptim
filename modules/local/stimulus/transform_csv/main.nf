
process STIMULUS_TRANSFORM_CSV {

    tag "${meta.id}-${meta2.id}"
    label 'process_medium'
    // TODO: push image to nf-core quay.io
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(data)
    tuple val(meta2), path(config)

    output:
    tuple val(meta), path("${prefix}.csv"), emit: transformed_data
    path "versions.yml"          , emit: versions

    script:
    prefix = task.ext.prefix ?: "${meta.id}-${meta2.id}-trans"
    """
    stimulus transform-csv \
        -c ${data} \
        -y ${config} \
        -o ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}-${meta2.id}-trans"
    """
    touch ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
