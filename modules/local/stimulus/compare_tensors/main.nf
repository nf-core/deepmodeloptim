process STIMULUS_COMPARE_TENSORS {
    tag "${meta.id}"
    label 'process_medium'
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(tensors)

    output:
    tuple val(meta), path("${prefix}_scores.csv"), emit: csv
    path "versions.yml"          , emit: versions

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ""
    def header = meta.keySet().join(",")
    def values = meta.values().join(",")
    """
    stimulus compare-tensors \
        ${tensors} \
        -o "${prefix}_scores.csv" \
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: meta.id
    """
    touch ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
