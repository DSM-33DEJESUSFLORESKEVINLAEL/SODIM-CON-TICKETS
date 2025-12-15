class MOrden {
  final String? orden;
  final String? marbete;
  final String? economico;
  final String? matricula;
  final String? medida;
  final String? marca;
  final String? trabajo;
  final String? terminado;
  final String? banda;
  final String? pr;
  final String? nup;
  final String? oriren;
  final String? falla;
  final String? ajuste;
  final String? docajuste;
  final String? faj;
  final String? oaj;
  final String? reprocesos;
  final String? status;
  final String? reparaciones;
  final String? frev;
  final String? orev;
  final String? farm;
  final String? oarm;
  final String? fcal;
  final String? ocal;
  final String? ubicacion;
  final String? documento;
  // ignore: non_constant_identifier_names
  final String? env_suc;
  final String? fsalida;
  final String? docsalida;
  final String? fentrada;
  final String? docentrada;
  final String? control;
  final String? oras;
  final String? ocar;
  final String? opre;
  final String? orep;
  final String? oenc;
  final String? ores;
  final String? ovul;
  final String? fdocumento;
  final String? fras;
  final String? frep;
  final String? fvul;
  final String? fcar;
  final String? sg;
  final String? bus;
  final String? trabajoalterno;
  final String? observacion1;
  final String? observacion2;
  final String? refac;
  final String? mesdoc;
  final String? aniodoc;
    // ignore: non_constant_identifier_names
  final String? ter_anterior;
  final String? nrenovado;
  final String? ajusteimporte;
    // ignore: non_constant_identifier_names
  final String? marbete_ant;
  final String? autoclave;
    // ignore: non_constant_identifier_names
  final String? rev_xerografia;
  final String? obs;
    // ignore: non_constant_identifier_names
  final String? codigo_tra;
  final String? compuesto;
    // ignore: non_constant_identifier_names
  final String? trabajo_otr;
    // ignore: non_constant_identifier_names
  final String? anio_calidad;
    // ignore: non_constant_identifier_names
  final String? mes_calidad;
  final String? fentcascosren;
  final String? dentcascosren;
  final String? uentcascosren;
    // ignore: non_constant_identifier_names
  final String? cte_distribuidor;
  final String? datoextra1;
    // ignore: non_constant_identifier_names
  final String? falla_armado;    
  // ignore: non_constant_identifier_names
  final String? fincidencia_armado;
  final String? perdido;
      // ignore: non_constant_identifier_names
  final String? fperdido;
        // ignore: non_constant_identifier_names
  final String? clie_tipo;
        // ignore: non_constant_identifier_names
  final String? causa_atrazo;
  final String? fabricante;
        // ignore: non_constant_identifier_names
  final String? articulo_pronostico;
  final String? sobre;
        // ignore: non_constant_identifier_names
  final String? nc_docto;
        // ignore: non_constant_identifier_names
  final String? nc_fecha;
        // ignore: non_constant_identifier_names
  final String? nc_usuario;
        // ignore: non_constant_identifier_names
  final String? tipo_cardeado;
        // ignore: non_constant_identifier_names
  final String? marbete_ic;      
  // ignore: non_constant_identifier_names
  final String? terminado_cte_ic;
  final String? ic;
        // ignore: non_constant_identifier_names
  final String? articulo_pt;
  final String? tarima;
        // ignore: non_constant_identifier_names
  final String? reg_tarima;
  final String? opar;
  final String? fpar;
        // ignore: non_constant_identifier_names
  final String? rep_parches;
  final String? ogur0tr;
  final String? fgur0tr;
  final String? olavotr;
  final String? flavotr;
  final String? oencotr;
  final String? fencotr;
  final String? oresotr;
  final String? fresotr;
  final String? occeotr;
  final String? fcceotr;
        // ignore: non_constant_identifier_names
  final String? otr_kilos_arm;
        // ignore: non_constant_identifier_names
  final String? otr_kilos_car;
        // ignore: non_constant_identifier_names
  final String? articulo_revisado;
  final String? opulotr;
  final String? fpulotr;
        // ignore: non_constant_identifier_names
  final String? lote_tira;
  final String? sumacalidad;
        // ignore: non_constant_identifier_names
  final String? dias_entrega;

  MOrden({
     this.orden,
     this.marbete,
     this.economico,
     this.matricula,
     this.medida,
     this.marca,
     this.trabajo,
     this.terminado,
     this.banda,
     this.pr,
     this.nup,
     this.oriren,
     this.falla,
     this.ajuste,
     this.docajuste,
     this.faj,
     this.oaj,
     this.reprocesos,
     this.status,
     this.reparaciones,
     this.frev,
     this.orev,
     this.farm,
     this.oarm,
     this.fcal,
     this.ocal,
     this.ubicacion,
     this.documento,
     this.env_suc,
     this.fsalida,
     this.docsalida,
     this.fentrada,
     this.docentrada,
     this.control,
     this.oras,
     this.ocar,
     this.opre,
     this.orep,
     this.oenc,
     this.ores,
     this.ovul,
     this.fdocumento,
     this.fras,
     this.frep,
     this.fvul,
     this.fcar,
     this.sg,
     this.bus,
     this.trabajoalterno,
     this.observacion1,
     this.observacion2,
     this.refac,
     this.mesdoc,
     this.aniodoc,
     this.ter_anterior,
     this.nrenovado,
     this.ajusteimporte,
     this.marbete_ant,
     this.autoclave,
     this.rev_xerografia,
     this.obs,
     this.codigo_tra,
     this.compuesto,
     this.trabajo_otr,
     this.anio_calidad,
     this.mes_calidad,
     this.fentcascosren,
     this.dentcascosren,
     this.uentcascosren,
     this.cte_distribuidor,
     this.datoextra1,
     this.falla_armado,
     this.fincidencia_armado,
     this.perdido,
     this.fperdido,
     this.clie_tipo,
     this.causa_atrazo,
     this.fabricante,
     this.articulo_pronostico,
     this.sobre,
          // ignore: non_constant_identifier_names
     this.nc_docto,
     this.nc_fecha,
     this.nc_usuario,
     this.tipo_cardeado,
     this.marbete_ic,
     // ignore: non_constant_identifier_names
     this.terminado_cte_ic,
     this.ic,
     // ignore: non_constant_identifier_names
     this.articulo_pt,
     this.tarima,
     // ignore: non_constant_identifier_names
     this.reg_tarima,
     this.opar,
     this.fpar,
          // ignore: non_constant_identifier_names
     this.rep_parches,
     this.ogur0tr,
     this.fgur0tr,
     this.olavotr,
     this.flavotr,
     this.oencotr,
     this.fencotr,
     this.oresotr,
     this.fresotr,
     this.occeotr,
     this.fcceotr,
          // ignore: non_constant_identifier_names
     this.otr_kilos_arm,
          // ignore: non_constant_identifier_names
     this.otr_kilos_car,
          // ignore: non_constant_identifier_names
     this.articulo_revisado,
     this.opulotr,
     this.fpulotr,
          // ignore: non_constant_identifier_names
     this.lote_tira,
     this.sumacalidad,
          // ignore: non_constant_identifier_names
     this.dias_entrega,
  });


  factory MOrden.fromJson(Map<String?, dynamic> json) => MOrden(
        orden: json['ORDEN'],
        marbete: json['MARBETE'],
        economico: json['ECONOMICO'],
        matricula: json['MATRICULA'],
        trabajo: json['TRABAJO'],
        status: json['STATUS'],
        observacion1: json['OBSERVACION1'],
        observacion2: json['OBSERVACION2'],
        terminado: json['TERMINADO'],
        ubicacion: json['UBICACION'],
      );

  Map<String?, dynamic> toJson() => {
        'ORDEN': orden,
        'MARBETE': marbete,
        'ECONOMICO': economico,
        'MATRICULA': matricula,
        'TRABAJO': trabajo,
        'STATUS': status,
        'OBSERVACION1': observacion1,
        'OBSERVACION2': observacion2,
        'TERMINADO': terminado,
        'UBICACION': ubicacion,
      };

  factory MOrden.fromMap(Map<String?, dynamic> map) => MOrden(
        orden: map['orden'],
        marbete: map['marbete'],
        economico: map['economico'],
        matricula: map['matricula'],
        trabajo: map['trabajo'],
        status: map['status'],
        observacion1: map['observacion1'],
        observacion2: map['observacion2'],
        terminado: map['terminado'],
        ubicacion: map['ubicacion'],
      );

  Map<String, dynamic> toMap() => {
        'orden': orden,
        'marbete': marbete,
        'economico': economico,
        'matricula': matricula,
        'trabajo': trabajo,
        'status': status,
        'observacion1': observacion1,
        'observacion2': observacion2,
        'terminado': terminado,
        'ubicacion': ubicacion,
      };
}
