/* Tabulate JSON data using D3.js */
var acronyms = {
   // Peptides
   'n_pep_ids' : 'number of redundant peptide identifications, filtered for decoys and contaminants',
   'n_pep_qts' : 'number of redundant peptide quantitations',
   'n_unq_pep_seq+mod_ids' : 'number of non-redundant peptide identifications unique by sequence and modifications',
   'n_unq_pep_seq+mod_qts' : 'number of non-redundant peptide quantitations unique by sequence and modifications',
   'n_unq_pep_seq_ids' : 'number of non-redundant peptide identifications unique by sequence',
   'n_unq_pep_seq_qts' : 'number of non-redundant peptide quantitations unique by sequence',
   'n_pep_ids_decoys' : 'number of redundant peptides detected as false positives (decoys)',
   'n_pep_ids_conts' : 'number of redundant peptides detected as contaminants',
   'n_unq_pep_seq_decoys' : 'number of non-redundant peptide decoys unique by sequence',
   'n_unq_pep_seq_conts' : 'number of non-redundant peptide contaminants unique by sequence',

   // Proteins
   'db' : 'source database/section (UniProtKB/Swiss-Prot or UniProtKB/TrEMBL)',
   'n_prot_acc' : 'number of protein accessions including isoforms in the source database (or FASTA sequence library)',
   'n_prot_ids' : 'number of identified (inferred) protein accessions',
   'n_prot_acc_evid_protein' : 'number of protein accessions with protein-level evidence',
   'n_prot_acc_evid_transcript' : 'number of protein accessions with transcript-level evidence',
   'n_prot_acc_evid_homology' : 'number of protein accessions with homology-based evidence',
   'n_prot_acc_evid_predicted' : 'number of in silico predicted proteins',
   'n_prot_acc_evid_uncertain' : 'number of protein accessions with uncertain evidence',

   // Protein groups
   'exp_name' : 'experiment name',
   'n_pgrp_ids' : 'number of non-redundant protein identifications, filtered for decoys and contaminants',
   'n_pgrp_qts' : 'number of non-redundant protein quantitations',
   'n_pgrp_ids_by_site' : 'number of non-redudant proteins identified by modification site',
   'n_pgrp_decoys' : 'number of non-redundant proteins detected as false positives (decoys)',
   'n_pgrp_conts' : 'number of non-redundant proteins detected as contaminants',

   // Regulated proteins (groups)
   'n_pgrp_ids_all' : 'union of differentially regulated proteins identified in all conditions, filtered for decoys and contaminants',
   'n_pgrp_ids_H/L+L/H' : 'number of up- AND down-regulated proteins identified in both conditions H/L and L/H',
   'n_pgrp_ids_H/L' : 'number of up- OR down-regulated proteins identified in the H/L condition',
   'n_pgrp_ids_L/H' : 'number of up- OR down-regulated proteins identified in the L/H condition',
   'n_pgrp_ids_H/M+M/H' : 'number of up- AND down-regulated proteins identified in both conditions H/M and M/H',
   'n_pgrp_ids_H/M' : 'number of up- OR down-regulated proteins identified in the H/M condition',
   'n_pgrp_ids_M/H' : 'number of up- OR down-regulated proteins identified in the M/H condition',
   'n_pgrp_ids_M/L+L/M' : 'number of up- AND down-regulated proteins identified in both conditions M/L and L/M',
   'n_pgrp_ids_M/L' : 'number of up- OR down-regulated proteins identified in the M/L condition',
   'n_pgrp_ids_L/M' : 'number of up- OR down-regulated proteins identified in the L/M condition'
};


function tabulate(json, elem) {
    var table = d3.select(elem)
        .append("table")
        .attr("class", "table table-hover table-bordered");

    var thead = table.append("thead")
        .append("tr")
        .selectAll("th")
        .data(d3.keys(json[0]))
        .enter().append("th")
        .attr("title", function(d) { return (acronyms[d] !== undefined) ? acronyms[d] : '-'; })
        .text(function(d) { return d; });

    var tbody = table.append("tbody")
       .selectAll("tr")
        .data(json)
        .enter().append("tr")
        .selectAll("td")
        .data(function(d) { return d3.values(d); })
        .enter().append("td")
        .text(function(d) { return d; });
}


/* Draw barchart from JSON data using D3.js */
function drawChart(json, elem) {
    var xlab, ylab, attr;

    if (elem.match(/statpep/)) {
      attr = "exp_name";
      xlab = "Experiment";
      ylab = "Number of peptides";
    } else if (elem.match(/statprot/)) {
        attr = "db";
        xlab = "Database/section";
        ylab = "Number of proteins";
    } else if (elem.match(/statgrp/)) {
        attr = "exp_name";
        xlab = "Experiment";
        ylab = "Number of protein groups";
    } else if (elem.match(/statregrp/)) {
        attr = "exp_name";
        xlab = "Experiment";
        ylab = "Number of regulated protein groups FC\u22651.5 [P<.05]";
    }

    var attrNames = d3.keys(json[0]).filter(function(key) {
        return key !== attr;
    });
    var categories = json.map(function(d) {
        var val = (elem.match(/statprot/) != null) ? d.db : d.exp_name;
        return val;
    });

    json.forEach(function(d) {  // transform JSON data
        d.values = attrNames.map(function(name) {
            kv = { name: name, value: +d[name] };
            delete d[name];
            return kv;
        });
    });

    var margin = { top: 50, right: 235, bottom: 50, left: 65 },
        w1 = categories.length * 160,
        w2 = 800 - margin.left - margin.right,
        width = (w1 > w2) ? w1 : w2;
        height = 480 - margin.top - margin.bottom;

    var color = d3.scaleOrdinal(d3.schemeCategory10);
    var maxValue = d3.max(json, function(d) {
        return d3.max(d.values, function(d) {
            return d.value;
        });
    });

    var x0 = d3.scaleBand()
        .domain(categories)
        .rangeRound([0, width], .1);
    var x1 = d3.scaleBand()
        .domain(attrNames)
        .rangeRound([0, x0.bandwidth()]);
    var y = d3.scaleLinear()
        .domain([0, maxValue])
        .range([height, 0])
        .nice();
    var fmtype = (maxValue > 1000) ? ".2s" : "d";
    var xAxis = d3.axisBottom(x0);
    var yAxis = d3.axisLeft(y).tickFormat(d3.format(fmtype));
    var svg = d3.select(elem)
        .append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .attr("style", "background-color: white;")
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    svg.append("g")
        .attr("class", "xAxis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis);

    svg.select(".xAxis").select("path").attr("style", "display: none;");
    svg.select(".xAxis").selectAll("line").attr("style", "fill: none; stroke: black;");

    svg.append("text")
        .attr("class", "xLabel")
        .attr("x", width / 2)
        .attr("y", height)
        .attr("dy", "2.5em")
        .attr("style", "text-anchor: middle; font: 14px sans-serif; font-weight: bold;")
        .text(xlab);

    svg.append("g")
        .attr("class", "yAxis")
        .call(yAxis);

    svg.select(".yAxis").select("path").attr("style", "fill: none; stroke: black;");
    svg.select(".yAxis").selectAll("line").attr("style", "fill: none; stroke: black;");

    svg.append("text")
        .attr("class", "yLabel")
        .attr("transform", "rotate(-90)")
        .attr("y", 0 - margin.left)
        .attr("dy", "1em")
        .attr("x", 0 - (height / 2))
        .attr("style", "text-anchor: middle; font: 14px sans-serif; font-weight: bold;")
        .text(ylab);

    var experiment = svg.selectAll(".experiment")
        .data(json)
        .enter().append("g")
        .attr("class", "g")
        .attr("transform", function(d) {
            var val = (elem.match(/statprot/) != null) ? d.db : d.exp_name;
            return "translate(" + x0(val) + ",0)";
        });

    experiment.selectAll("rect")
        .data(function(d) { return d.values; })
        .enter().append("rect")
        .attr("x", function(d) { return x1(d.name); })
        .attr("y", function(d) { return y(d.value); })
        .attr("height", function(d) { return height - y(d.value); })
        .attr("width", x1.bandwidth())
        .style("fill", function(d) { return color(d.name); })
        .append("svg:title").text(function(d) { return(d.value); });

    var legend = svg.selectAll(".legend")
        .data(attrNames)
        .enter().append("g")
        .attr("class", "legend")
        .attr("transform", function(d, i) { return "translate(0," + i * 15 + ")"; });

    legend.append("rect")
        .attr("x", width)
        .attr("y", margin.top)
        .attr("width", 10)
        .attr("height", 10)
        .style("fill", color);

    legend.append("text")
        .attr("x", width)
        .attr("y", margin.top)
        .attr("dx", "1.2em")
        .attr("dy", "0.6em")
        .attr("style", "text-anchor: right; font: 12px sans-serif;")
        .text(function(d) { return d; })
        .append("svg:title").text(function(d) {
           return (acronyms[d] !== undefined) ? acronyms[d] : '-';
        });
}


/* Define jqGrid column formatters */
function grpIdFormat(cellValue, options, rowObject) {
    var sessionId = options.colModel.formatoptions.sessionId;
    var grpId = cellValue;
    return '<a href="../pepmap/' + sessionId + '?grp_id=' + grpId + '" class="link" target="_blank" title="Show peptide map">' + grpId + '</a>';
}

function protNamesFormat(cellValue, options, rowObject) {
/*
 * Input:
 *   "name1","name2",...
 *
 * Output:
 *   name1,
 *   name2,
 *   ...
*/
    if (cellValue == null) { return '-'; }
    var names = cellValue.split('","');
    for (var i = 0; i < names.length; i++) {
        names[i] = names[i].replace(/"/g, '');
    }
    return names.join(',<br />');
}

function geneNamesFormat(cellValue, options, rowObject) {
/*
 * Input:
 *   "name1,name2",...
 *
 * Output:
 *   name1,
 *   name2,
 *   ...
*/
    if (cellValue == null) { return '-'; }
    var names = cellValue.split(',');
    for (var i = 0; i < names.length; i++) {
        names[i] = names[i].replace(/"/g, '');
    }
    return names.join(',<br />');
}


function protAccFormat(cellValue, options, rowObject) {
/*
 * Input:
 *   "db1:acc1,db1:acc2,db2:acc3,..."
 *
 * Output:
 *   db1:
 *     acc1 acc2 ...
 *
 *   db2:
 *     acc3
*/
    var entries = cellValue.split(',');
    var url = 'http://www.uniprot.org/uniprot/';
    var curDb = new String();

    for (var i = 0; i < entries.length; i++) {
        var db_acc = entries[i].replace(/"/g, '').split(':');
        var db = db_acc[0], acc = db_acc[1];

        if(i == 0) {
            curDb = db;
            cellValue = '<b>' + db + '</b>' + ':' + '<br />';
        }

        if (curDb != db) {
            cellValue +=  '<br /><br /><b>' + db + '</b>' + ':' + '<br />';
         }

        cellValue += '<a href="' + url + acc + '" target="_blank" title="Link to UniProtKB" class="link">' + acc + "</a>&nbsp;";
        curDb = db;
    }
    return cellValue;
}


function toExponentialFormat(cellValue, options, rowObject) {
    var retValue = (!isNaN(+cellValue) && isFinite(cellValue) && cellValue != null) ? cellValue.toExponential() : '-';
    return retValue;
}


/* Define searchable jqGrid table */
function searchableGrid(url, elem, sessionId, expStates) {
    // set defaults
    var defaultRatio = 1.5;
    var defaultPval = 0.05;
    var HL = "norm_ratio_HL";
    var LH = "norm_ratio_LH";
    var HM = "norm_ratio_HM";
    var MH = "norm_ratio_MH";
    var ML = "norm_ratio_ML";
    var LM = "norm_ratio_LM";

    var templateDuplex1 = {
        groupOp: "OR",
        groups: [
            { groupOp: "AND",
            rules: [
                { field: HL, op: "ge", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: LH, op: "ge", data: defaultRatio }
            ]}
        ]
    };

    var templateTriplex1 = {
        groupOp: "OR",
        groups: [
            { groupOp: "AND",
            rules: [
                { field: HL, op: "ge", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: LH, op: "ge", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: HM, op: "ge", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: MH, op: "ge", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: ML, op: "ge", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: LM, op: "ge", data: defaultRatio }
            ]}
        ]
    };

    var templateDuplex2 = {
        groupOp: "OR",
        groups: [
            { groupOp: "AND",
            rules: [
                { field: HL, op: "ge", data: defaultRatio },
                { field: "sig_ratio_HL", op: "lt", data: defaultPval }
            ]},
            { groupOp: "AND",
            rules: [
                { field: LH, op: "ge", data: defaultRatio },
                { field: "sig_ratio_HL", op: "lt", data: defaultPval }
            ]}
        ]
    };

    var templateTriplex2 = {
        groupOp: "OR",
        groups: [
            { groupOp: "AND",
            rules: [
                { field: HL, op: "ge", data: defaultRatio },
                { field: "sig_ratio_HL", op: "lt", data: defaultPval }
            ]},
            { groupOp: "AND",
            rules: [
                { field: LH, op: "ge", data: defaultRatio },
                { field: "sig_ratio_HL", op: "lt", data: defaultPval }
            ]},
            { groupOp: "AND",
            rules: [
                { field: HM, op: "ge", data: defaultRatio },
                { field: "sig_ratio_HM", op: "lt", data: defaultPval }
            ]},
            { groupOp: "AND",
            rules: [
                { field: MH, op: "ge", data: defaultRatio },
                { field: "sig_ratio_HM", op: "lt", data: defaultPval }
            ]},
            { groupOp: "AND",
            rules: [
                { field: ML, op: "ge", data: defaultRatio },
                { field: "sig_ratio_ML", op: "lt", data: defaultPval }
            ]},
            { groupOp: "AND",
            rules: [
                { field: LM, op: "ge", data: defaultRatio },
                { field: "sig_ratio_ML", op: "lt", data: defaultPval }
            ]}
        ]
    };

    var template1 = (expStates == 2) ? templateDuplex1 : templateTriplex1;
    var template2 = (expStates == 2) ? templateDuplex2 : templateTriplex2;
    var grid = $(elem);
    grid.jqGrid({
        caption: "Search for candidate proteins",
        url: url,
        datatype: "json",
        height: 500,
        //postData: { filters: defaultFilter },
        colNames: [
            "GroupID",
            "Size",
            "Experiment",
            "Protein accessions",
            "Protein names",
            "Evidence",
            "Genes",
            "Organism",
            "PEP",
            "H/L",
            "L/H",
            "H/M",
            "M/H",
            "M/L",
            "L/M",
            "Nq HL",
            "Nq HM",
            "Nq ML",
            "SD HL",
            "SD HM",
            "SD ML",
            "Sig HL",
            "Sig HM",
            "Sig ML"
        ],
        colModel: [
            { name: "grp_id", index: "grp_id", width: 60, sorttype: "int", align: "center", formatter: grpIdFormat, formatoptions: { sessionId: sessionId }, searchrule: { minValue: 1 }, searchoptions: { sopt: ['eq', 'ne'] } },
            { name: "grp_size", index: "grp_size", width: 60, sorttype: "int", align: "center", formatter: "number", formatoptions: { decimalPlaces: 0 }, searchrule: { minValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "exp_name", index: "exp_name", width: 80, sorttype: "String", align: "center", searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn'] } },
            { name: "prot_accs", index: "prot_accs", width: 140, sorttype: "String", align: "left", formatter: protAccFormat, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn'] } },
            { name: "prot_names", index: "prot_names", width: 140, sorttype: "String", align: "center", formatter: protNamesFormat, formatoptions: { defaultValue: '-' }, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn', 'nu', 'nn'] } },
            { name: "grp_evidence", index: "grp_evidence", width: 60, sorttype: "String", align: "center", stype: "select", searchoptions: { sopt: ['eq', 'ne'], value: "protein:protein;transcript:transcript;homology:homology;predicted:predicted;uncertain:uncertain;unknown:unknown" } },
            { name: "gene_names", index: "gene_names", width: 80, sorttype: "String", align: "center", formatter: geneNamesFormat, formatoptions: { defaultValue: '-' }, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn', 'nu', 'nn'] } },
            { name: "org", index: "org", width: 100, sorttype: "String", align: "center", formatoptions: { defaultValue: '-' }, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn'] } },
            { name: "pep_score", index: "pep_score", width: 50, sorttype: "float", align: "center", formatter: toExponentialFormat, formatoptions: { defaultValue: '-' }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "norm_ratio_HL", index: "norm_ratio_HL", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "norm_ratio_LH", index: "norm_ratio_LH", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "norm_ratio_HM", index: "norm_ratio_HM", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "norm_ratio_MH", index: "norm_ratio_MH", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "norm_ratio_ML", index: "norm_ratio_ML", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "norm_ratio_LM", index: "norm_ratio_LM", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "n_pep_qts_HL", index: "n_pep_qts_HL", width: 50, sorttype: "int", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 0 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'eq', 'ne'] } },
            { name: "n_pep_qts_HM", index: "n_pep_qts_HM", width: 50, sorttype: "int", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 0 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'eq', 'ne'] } },
            { name: "n_pep_qts_ML", index: "n_pep_qts_ML", width: 50, sorttype: "int", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 0 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'eq', 'ne'] } },
            { name: "sd_ratio_HL", index: "sd_ratio_HL", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "sd_ratio_HM", index: "sd_ratio_HM", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "sd_ratio_ML", index: "sd_ratio_ML", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "sig_ratio_HL", index: "sig_ratio_HL", width: 60, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 4 }, searchrules: { minValue: 0, maxValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "sig_ratio_HM", index: "sig_ratio_HM", width: 60, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 4 }, searchrules: { minValue: 0, maxValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } },
            { name: "sig_ratio_ML", index: "sig_ratio_ML", width: 60, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 4 }, searchrules: { minValue: 0, maxValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'nu', 'nn'] } }
        ],
        cmTemplate: { title: false }, // disable tooltip
        pager: "#pager",
        rowNum: 50,
        rowList: [10, 25, 50, 100],
        loadonce: true,
        rownumbers: false,
        viewrecords: true,
        ignoreCase: true,
        //beforeSelectRow: function() { return false; } // disable row selection
        //width: 800,
        //height: "100%"
    }).navGrid("#pager",
        { view: true, edit: false, add: false, del: false, searchtext: 'Search&nbsp;', refreshtext: 'Refresh&nbsp;' },
        { /* Edit options */ },
        { /* Add options */ },
        { /* Del options */ },
        {
            caption: "Query builder",
            multipleSearch: true,
            multipleGroup: true,
            showQuery: false,
            searchOnEnter: true,
            recreateFilter: true,
            closeOnEscape: true,
            closeAfterSearch: false,
            groupOps: [{ op: "AND", text: "AND" }, { op: "OR", text: "OR" }],
            tmplNames : [ "Select all regulated proteins (FC&ge;1.5)",
                          "Select all regulated proteins (FC&ge;1.5; P-value&lt;.05)" ],
            tmplFilters : [ template1, template2 ]
        });
        //.trigger("reloadGrid");
        //.unbind("mouseover mouseout") // turn off hover
        //.setGridParam({
        //  search: false
        //grid.jqGrid("filterToolbar", { searchOperators : true });
        // add tooltips to header columns
        grid.jqGrid('setLabel', 'grp_id', '', {}, {'title': 'Protein group ID (for internal use)'});
        grid.jqGrid('setLabel', 'grp_size', '', {}, {'title': "Protein group's size"});
        grid.jqGrid('setLabel', 'exp_name', '', {}, {'title': 'Experiment name'});
        grid.jqGrid('setLabel', 'prot_accs', '', {}, {'title': 'Protein accessions from the UniProtKB database'});
        grid.jqGrid('setLabel', 'prot_names', '', {}, {'title': 'Recommended names of the protein accessions in the group'});
        grid.jqGrid('setLabel', 'grp_evidence', '', {}, {'title': 'Highest level of evidence for the protein accession(s) in the group [protein/transcript/homology/predicted/uncertain/unknown]'});
        grid.jqGrid('setLabel', 'gene_names', '', {}, {'title': 'Official gene names of the protein accessions in the group'});
        grid.jqGrid('setLabel', 'org', '', {}, {'title': 'Species name'});
        grid.jqGrid('setLabel', 'pep_score', '', {}, {'title': 'Posterior Error Probability of the protein identification (P-value)'});
        grid.jqGrid('setLabel', 'norm_ratio_HL', '', {}, {'title': 'Normalized protein ratio H/L'});
        grid.jqGrid('setLabel', 'norm_ratio_LH', '', {}, {'title': 'Normalized protein ratio L/H'});
        grid.jqGrid('setLabel', 'norm_ratio_HM', '', {}, {'title': 'Normalized protein ratio H/M'});
        grid.jqGrid('setLabel', 'norm_ratio_MH', '', {}, {'title': 'Normalized protein ratio M/H'});
        grid.jqGrid('setLabel', 'norm_ratio_ML', '', {}, {'title': 'Normalized protein ratio M/L'});
        grid.jqGrid('setLabel', 'norm_ratio_LM', '', {}, {'title': 'Normalized protein ratio L/M'});
        grid.jqGrid('setLabel', 'n_pep_qts_HL', '', {}, {'title': 'Number of peptide quantitations used to estimate the protein ratio H/L (L/M)'});
        grid.jqGrid('setLabel', 'n_pep_qts_HM', '', {}, {'title': 'Number of peptide quantitations used to estimate the protein ratio H/M (M/H)'});
        grid.jqGrid('setLabel', 'n_pep_qts_ML', '', {}, {'title': 'Number of peptide quantitation used to estimate the protein ratio M/L (L/M)'});
        grid.jqGrid('setLabel', 'sd_ratio_HL', '', {}, {'title': 'Standard deviation of the log2 peptide ratios H/L (L/M)'});
        grid.jqGrid('setLabel', 'sd_ratio_HM', '', {}, {'title': 'Standard deviation of the log2 peptide ratios H/M (M/H)'});
        grid.jqGrid('setLabel', 'sd_ratio_ML', '', {}, {'title': 'Standard deviation of the log2 peptide ratios M/L (L/M)'});
        grid.jqGrid('setLabel', 'sig_ratio_HL', '', {}, {'title': 'Peak intensity-based significance B of the protein ratio H/L (L/M) (adj. p-value)'});
        grid.jqGrid('setLabel', 'sig_ratio_HM', '', {}, {'title': 'Peak intensity-based significance B of the protein ratio H/M (M/H) (adj. p-value)'});
        grid.jqGrid('setLabel', 'sig_ratio_ML', '', {}, {'title': 'Peak intensity-based significance B of the protein ratio M/L (M/L) (adj. p-value)'});

        if (expStates == 2) { // for duplex SILAC experiments hide some columns
           grid.jqGrid('hideCol', ['norm_ratio_HM', 'norm_ratio_MH', 'norm_ratio_ML', 'norm_ratio_LM', 'n_pep_qts_HM', 'n_pep_qts_ML', 'sd_ratio_HM', 'sd_ratio_ML', 'sig_ratio_HM', 'sig_ratio_ML']).trigger("reloadGrid");
        }

       /*$("#mySearch").click(function(){
           var text = $("#searchText").val();
           var postdata = grid.jqGrid('getGridParam', 'postData');
           $.extend(postdata, { filters: '', searchField: 'prot_names', searchField: 'genes', searchOper: 'cn', searchString: text });
           grid.jqGrid('setGridParam', { search: text.length > 0, postData: postdata });
           grid.trigger("reloadGrid", [ { page: 1 } ]);
       });*/
}


function tabulateScatterplotData(elem, json, sessionId) {
    var r1 = "log2_ratio1";
    var r2 = "log2_ratio2";
    var s1 = "sig_ratio1";
    var s2 = "sig_ratio2";
    var defaultRatio = 0;
    var template1 = {
        groupOp: "OR",
        groups: [
            { groupOp: "AND",
            rules: [
                { field: r1, op: "gt", data: defaultRatio },
                { field: r2, op: "gt", data: defaultRatio }
            ]},
            { groupOp: "AND",
            rules: [
                { field: r1, op: "lt", data: defaultRatio },
                { field: r2, op: "lt", data: defaultRatio }
            ]}
        ]
    };
    var grid = jQuery(elem);

    grid.jqGrid({
        caption: "Tabulated scatterplot data",
        datastr: json,
        datatype: "jsonstring",
        height: 500,
        colNames: [
            "GroupID",
            "Size",
            "Protein accessions",
            "Protein names",
            "Evidence",
            "Genes",
            "Organism",
            "log2R1",
            "log2R2",
            "FC1",
            "FC2",
            "SD1",
            "SD2",
            "Nq1",
            "Nq2",
            "Sig1",
            "Sig2"
        ],
        colModel: [
            { name: "grp_id", index: "grp_id", width: 60, sorttype: "int", align: "center", formatter: grpIdFormat, formatoptions: { sessionId: sessionId }, searchrule: { minValue: 1 }, searchoptions: { sopt: ['eq', 'ne'] } },
            { name: "grp_size", index: "grp_size", width: 60, sorttype: "int", align: "center", formatter: "number", formatoptions: { decimalPlaces: 0 }, searchrule: { minValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "prot_accs", index: "prot_accs", width: 140, sorttype: "String", align: "left", formatter: protAccFormat, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn'] } },
            { name: "prot_names", index: "prot_names", width: 140, sorttype: "String", align: "center", formatter: protNamesFormat, formatoptions: { defaultValue: '-' }, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn', 'nu', 'nn'] } },
            { name: "grp_evidence", index: "grp_evidence", width: 60, sorttype: "String", align: "center", stype: "select", searchoptions: { sopt: ['eq', 'ne'], value: "protein:protein;transcript:transcript;homology:homology;predicted:predicted;uncertain:uncertain;unknown:unknown" } },
            { name: "gene_names", index: "gene_names", width: 80, sorttype: "String", align: "center", formatter: geneNamesFormat, formatoptions: { defaultValue: '-' }, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn', 'nu', 'nn'] } },
            { name: "org", index: "org", width: 100, sorttype: "String", align: "center", formatoptions: { defaultValue: '-' }, searchoptions: { sopt: ['cn', 'nc', 'eq', 'ne', 'bw', 'bn'] } },
            { name: "log2_ratio1", index: "log2_ratio1", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { decimalPlaces: 2 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "log2_ratio2", index: "log2_ratio2", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { decimalPlaces: 2 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "fc1", index: "fc1", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { decimalPlaces: 2 }, searchrules: { minValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "fc2", index: "fc2", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { decimalPlaces: 2 }, searchrules: { minValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },

            { name: "sd_ratio1", index: "sd_ratio1", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "sd_ratio2", index: "sd_ratio2", width: 50, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 2 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "n_pep_qts1", index: "n_pep_qts1", width: 50, sorttype: "int", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 0 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'eq', 'ne'] } },
            { name: "n_pep_qts2", index: "n_pep_qts2", width: 50, sorttype: "int", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 0 }, searchrules: { minValue: 0 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge', 'eq', 'ne'] } },
            { name: "sig_ratio1", index: "sig_ratio1", width: 60, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 4 }, searchrules: { minValue: 0, maxValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } },
            { name: "sig_ratio2", index: "sig_ratio2", width: 60, sorttype: "float", align: "center", formatter: "number", formatoptions: { defaultValue: '-', decimalPlaces: 4 }, searchrules: { minValue: 0, maxValue: 1 }, searchoptions: { sopt: ['lt', 'le', 'gt', 'ge'] } }
        ],
        cmTemplate: { title: false }, // disable tooltip
        pager: "#pager",
        rowNum: 50,
        rowList: [10, 25, 50, 100],
        loadonce: true,
        rownumbers: false,
        viewrecords: true,
        ignoreCase: true,
        //beforeSelectRow: function() { return false; } // disable row selection
        //width: 800,
        //height: "100%"
    }).navGrid("#pager",
        { view: true, edit: false, add: false, del: false, searchtext: 'Search&nbsp;', refreshtext: 'Refresh&nbsp;' },
        { /* Edit options */ },
        { /* Add options */ },
        { /* Del options */ },
        {
            caption: "Query builder",
            multipleSearch: true,
            multipleGroup: true,
            showQuery: false,
            searchOnEnter: true,
            recreateFilter: true,
            closeOnEscape: true,
            closeAfterSearch: false,
            groupOps: [{ op: "AND", text: "AND" }, { op: "OR", text: "OR" }],
            tmplNames : [ "Select proteins with consistent ratios" ],
            tmplFilters : [ template1 ]
        });//.unbind("mouseover mouseout") // turn off hover

        //.setGridParam({
        //  search: false
        //}).trigger("reloadGrid");
        //grid.jqGrid("filterToolbar", { searchOperators : true });
        // add tooltips to header columns
        grid.jqGrid('setLabel', 'grp_id', '', {}, {'title': 'Protein group ID (for internal use)'});
        grid.jqGrid('setLabel', 'grp_size', '', {}, {'title': "Protein group's size"});
        grid.jqGrid('setLabel', 'prot_accs', '', {}, {'title': 'Protein accessions from the UniProtKB database'});
        grid.jqGrid('setLabel', 'prot_names', '', {}, {'title': 'Recommended names of the protein accessions in the group'});
        grid.jqGrid('setLabel', 'grp_evidence', '', {}, {'title': 'Highest level of evidence for the protein accession(s) in the group [protein/transcript/homology/predicted/uncertain/unknown]'});
        grid.jqGrid('setLabel', 'gene_names', '', {}, {'title': 'Official gene names of the protein accessions in the group'});
        grid.jqGrid('setLabel', 'org', '', {}, {'title': 'Species name'});
        grid.jqGrid('setLabel', 'log2_ratio1', '', {}, {'title': 'Log2 protein ratio 1'});
        grid.jqGrid('setLabel', 'log2_ratio2', '', {}, {'title': 'Log2 protein ratio 2'});
        grid.jqGrid('setLabel', 'fc1', '', {}, {'title': 'Fold-change based on norm. protein ratio 1'});
        grid.jqGrid('setLabel', 'fc2', '', {}, {'title': 'Fold-change based on norm. protein ratio 2'});
        grid.jqGrid('setLabel', 'n_pep_qts1', '', {}, {'title': 'Number of peptide quantitations used to estimate the protein ratio 1'});
        grid.jqGrid('setLabel', 'n_pep_qts2', '', {}, {'title': 'Number of peptide quantitations used to estimate the protein ratio 2'});
        grid.jqGrid('setLabel', 'sd_ratio1', '', {}, {'title': 'Standard deviation of the log2 peptide ratios 1'});
        grid.jqGrid('setLabel', 'sd_ratio2', '', {}, {'title': 'Standard deviation of the log2 peptide ratios 2'});
        grid.jqGrid('setLabel', 'sig_ratio1', '', {}, {'title': 'Peak intensity-based significance B of the protein ratio 1 (adj. p-value)'});
        grid.jqGrid('setLabel', 'sig_ratio2', '', {}, {'title': 'Peak intensity-based significance B of the protein ratio 2 (adj. p-value)'});
}

/* Populate and submit the <FORM> with SVG data and requested output format */
function submitDownloadForm(output_format, query_string, session_id) {
    // Get the d3js SVG element
    var doc = document.getElementById(query_string);
    var svg = doc.getElementsByTagName('svg')[0];

    if (!svg) return;

    // Extract the data as SVG text string
    var svg_xml = (new XMLSerializer).serializeToString(svg);
    //alert(svg_xml);

    // Submit the <FORM> to the server.
    // The result will be an attachment file to download.
    var form = document.getElementById('svgform');
    form['session_id'].value = session_id;
    form['query_str'].value = query_string;
    form['output_format'].value = output_format;
    form['data'].value = svg_xml ;
    form.submit();
}

/* Construct URL with requested parameters */
function getURL(path, qpar, qkey, qval) {
    var qpars = [];

    if (qkey && qval) { // set query parameter
        qpar[qkey] = qval;
    }

    // store query parameters as key-value pairs
    for (qkey in qpar) {
        qpars.push(qkey + '=' + encodeURIComponent(qpar[qkey])); // encode special chars
    }

    return path + '?' + qpars.join('&amp;');
}
