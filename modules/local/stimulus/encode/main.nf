process ENCODE_CSV {

    tag "${meta.id}"
    label 'process_medium'
    // TODO: push image to nf-core quay.io
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(data)
    tuple val(meta2), path(config)

    output:
    tuple val(meta2), path("${prefix}_encoded"), emit: encoded
    path "versions.yml"          , emit: versions

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.split_id}-${meta2.transform_id}"
    """
    stimulus encode-csv \
        -d ${data} \
        -y ${config} \
        -o ${prefix}_encoded \
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    """
    echo passing check-model stub

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
