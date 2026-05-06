// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $BoitesTable extends Boites with TableInfo<$BoitesTable, BoiteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _officineIdMeta = const VerificationMeta(
    'officineId',
  );
  @override
  late final GeneratedColumn<String> officineId = GeneratedColumn<String>(
    'officine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cip13Meta = const VerificationMeta('cip13');
  @override
  late final GeneratedColumn<String> cip13 = GeneratedColumn<String>(
    'cip13',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lotMeta = const VerificationMeta('lot');
  @override
  late final GeneratedColumn<String> lot = GeneratedColumn<String>(
    'lot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numeroSerieMeta = const VerificationMeta(
    'numeroSerie',
  );
  @override
  late final GeneratedColumn<String> numeroSerie = GeneratedColumn<String>(
    'numero_serie',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peremptionMeta = const VerificationMeta(
    'peremption',
  );
  @override
  late final GeneratedColumn<String> peremption = GeneratedColumn<String>(
    'peremption',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitesInitialesMeta = const VerificationMeta(
    'unitesInitiales',
  );
  @override
  late final GeneratedColumn<int> unitesInitiales = GeneratedColumn<int>(
    'unites_initiales',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitesRestantesMeta = const VerificationMeta(
    'unitesRestantes',
  );
  @override
  late final GeneratedColumn<int> unitesRestantes = GeneratedColumn<int>(
    'unites_restantes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statutMeta = const VerificationMeta('statut');
  @override
  late final GeneratedColumn<String> statut = GeneratedColumn<String>(
    'statut',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ajouteeParMeta = const VerificationMeta(
    'ajouteePar',
  );
  @override
  late final GeneratedColumn<String> ajouteePar = GeneratedColumn<String>(
    'ajoutee_par',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    officineId,
    cip13,
    lot,
    numeroSerie,
    peremption,
    unitesInitiales,
    unitesRestantes,
    statut,
    notes,
    ajouteePar,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boites';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoiteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('officine_id')) {
      context.handle(
        _officineIdMeta,
        officineId.isAcceptableOrUnknown(data['officine_id']!, _officineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_officineIdMeta);
    }
    if (data.containsKey('cip13')) {
      context.handle(
        _cip13Meta,
        cip13.isAcceptableOrUnknown(data['cip13']!, _cip13Meta),
      );
    } else if (isInserting) {
      context.missing(_cip13Meta);
    }
    if (data.containsKey('lot')) {
      context.handle(
        _lotMeta,
        lot.isAcceptableOrUnknown(data['lot']!, _lotMeta),
      );
    }
    if (data.containsKey('numero_serie')) {
      context.handle(
        _numeroSerieMeta,
        numeroSerie.isAcceptableOrUnknown(
          data['numero_serie']!,
          _numeroSerieMeta,
        ),
      );
    }
    if (data.containsKey('peremption')) {
      context.handle(
        _peremptionMeta,
        peremption.isAcceptableOrUnknown(data['peremption']!, _peremptionMeta),
      );
    } else if (isInserting) {
      context.missing(_peremptionMeta);
    }
    if (data.containsKey('unites_initiales')) {
      context.handle(
        _unitesInitialesMeta,
        unitesInitiales.isAcceptableOrUnknown(
          data['unites_initiales']!,
          _unitesInitialesMeta,
        ),
      );
    }
    if (data.containsKey('unites_restantes')) {
      context.handle(
        _unitesRestantesMeta,
        unitesRestantes.isAcceptableOrUnknown(
          data['unites_restantes']!,
          _unitesRestantesMeta,
        ),
      );
    }
    if (data.containsKey('statut')) {
      context.handle(
        _statutMeta,
        statut.isAcceptableOrUnknown(data['statut']!, _statutMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('ajoutee_par')) {
      context.handle(
        _ajouteeParMeta,
        ajouteePar.isAcceptableOrUnknown(data['ajoutee_par']!, _ajouteeParMeta),
      );
    } else if (isInserting) {
      context.missing(_ajouteeParMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoiteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoiteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      officineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}officine_id'],
      )!,
      cip13: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cip13'],
      )!,
      lot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lot'],
      ),
      numeroSerie: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}numero_serie'],
      ),
      peremption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peremption'],
      )!,
      unitesInitiales: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unites_initiales'],
      ),
      unitesRestantes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unites_restantes'],
      ),
      statut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statut'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      ajouteePar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ajoutee_par'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $BoitesTable createAlias(String alias) {
    return $BoitesTable(attachedDatabase, alias);
  }
}

class BoiteRow extends DataClass implements Insertable<BoiteRow> {
  final String id;
  final String officineId;
  final String cip13;
  final String? lot;
  final String? numeroSerie;
  final String peremption;
  final int? unitesInitiales;
  final int? unitesRestantes;
  final String statut;
  final String? notes;
  final String ajouteePar;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  const BoiteRow({
    required this.id,
    required this.officineId,
    required this.cip13,
    this.lot,
    this.numeroSerie,
    required this.peremption,
    this.unitesInitiales,
    this.unitesRestantes,
    required this.statut,
    this.notes,
    required this.ajouteePar,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['officine_id'] = Variable<String>(officineId);
    map['cip13'] = Variable<String>(cip13);
    if (!nullToAbsent || lot != null) {
      map['lot'] = Variable<String>(lot);
    }
    if (!nullToAbsent || numeroSerie != null) {
      map['numero_serie'] = Variable<String>(numeroSerie);
    }
    map['peremption'] = Variable<String>(peremption);
    if (!nullToAbsent || unitesInitiales != null) {
      map['unites_initiales'] = Variable<int>(unitesInitiales);
    }
    if (!nullToAbsent || unitesRestantes != null) {
      map['unites_restantes'] = Variable<int>(unitesRestantes);
    }
    map['statut'] = Variable<String>(statut);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['ajoutee_par'] = Variable<String>(ajouteePar);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  BoitesCompanion toCompanion(bool nullToAbsent) {
    return BoitesCompanion(
      id: Value(id),
      officineId: Value(officineId),
      cip13: Value(cip13),
      lot: lot == null && nullToAbsent ? const Value.absent() : Value(lot),
      numeroSerie: numeroSerie == null && nullToAbsent
          ? const Value.absent()
          : Value(numeroSerie),
      peremption: Value(peremption),
      unitesInitiales: unitesInitiales == null && nullToAbsent
          ? const Value.absent()
          : Value(unitesInitiales),
      unitesRestantes: unitesRestantes == null && nullToAbsent
          ? const Value.absent()
          : Value(unitesRestantes),
      statut: Value(statut),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      ajouteePar: Value(ajouteePar),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory BoiteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoiteRow(
      id: serializer.fromJson<String>(json['id']),
      officineId: serializer.fromJson<String>(json['officineId']),
      cip13: serializer.fromJson<String>(json['cip13']),
      lot: serializer.fromJson<String?>(json['lot']),
      numeroSerie: serializer.fromJson<String?>(json['numeroSerie']),
      peremption: serializer.fromJson<String>(json['peremption']),
      unitesInitiales: serializer.fromJson<int?>(json['unitesInitiales']),
      unitesRestantes: serializer.fromJson<int?>(json['unitesRestantes']),
      statut: serializer.fromJson<String>(json['statut']),
      notes: serializer.fromJson<String?>(json['notes']),
      ajouteePar: serializer.fromJson<String>(json['ajouteePar']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'officineId': serializer.toJson<String>(officineId),
      'cip13': serializer.toJson<String>(cip13),
      'lot': serializer.toJson<String?>(lot),
      'numeroSerie': serializer.toJson<String?>(numeroSerie),
      'peremption': serializer.toJson<String>(peremption),
      'unitesInitiales': serializer.toJson<int?>(unitesInitiales),
      'unitesRestantes': serializer.toJson<int?>(unitesRestantes),
      'statut': serializer.toJson<String>(statut),
      'notes': serializer.toJson<String?>(notes),
      'ajouteePar': serializer.toJson<String>(ajouteePar),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  BoiteRow copyWith({
    String? id,
    String? officineId,
    String? cip13,
    Value<String?> lot = const Value.absent(),
    Value<String?> numeroSerie = const Value.absent(),
    String? peremption,
    Value<int?> unitesInitiales = const Value.absent(),
    Value<int?> unitesRestantes = const Value.absent(),
    String? statut,
    Value<String?> notes = const Value.absent(),
    String? ajouteePar,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => BoiteRow(
    id: id ?? this.id,
    officineId: officineId ?? this.officineId,
    cip13: cip13 ?? this.cip13,
    lot: lot.present ? lot.value : this.lot,
    numeroSerie: numeroSerie.present ? numeroSerie.value : this.numeroSerie,
    peremption: peremption ?? this.peremption,
    unitesInitiales: unitesInitiales.present
        ? unitesInitiales.value
        : this.unitesInitiales,
    unitesRestantes: unitesRestantes.present
        ? unitesRestantes.value
        : this.unitesRestantes,
    statut: statut ?? this.statut,
    notes: notes.present ? notes.value : this.notes,
    ajouteePar: ajouteePar ?? this.ajouteePar,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  BoiteRow copyWithCompanion(BoitesCompanion data) {
    return BoiteRow(
      id: data.id.present ? data.id.value : this.id,
      officineId: data.officineId.present
          ? data.officineId.value
          : this.officineId,
      cip13: data.cip13.present ? data.cip13.value : this.cip13,
      lot: data.lot.present ? data.lot.value : this.lot,
      numeroSerie: data.numeroSerie.present
          ? data.numeroSerie.value
          : this.numeroSerie,
      peremption: data.peremption.present
          ? data.peremption.value
          : this.peremption,
      unitesInitiales: data.unitesInitiales.present
          ? data.unitesInitiales.value
          : this.unitesInitiales,
      unitesRestantes: data.unitesRestantes.present
          ? data.unitesRestantes.value
          : this.unitesRestantes,
      statut: data.statut.present ? data.statut.value : this.statut,
      notes: data.notes.present ? data.notes.value : this.notes,
      ajouteePar: data.ajouteePar.present
          ? data.ajouteePar.value
          : this.ajouteePar,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoiteRow(')
          ..write('id: $id, ')
          ..write('officineId: $officineId, ')
          ..write('cip13: $cip13, ')
          ..write('lot: $lot, ')
          ..write('numeroSerie: $numeroSerie, ')
          ..write('peremption: $peremption, ')
          ..write('unitesInitiales: $unitesInitiales, ')
          ..write('unitesRestantes: $unitesRestantes, ')
          ..write('statut: $statut, ')
          ..write('notes: $notes, ')
          ..write('ajouteePar: $ajouteePar, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    officineId,
    cip13,
    lot,
    numeroSerie,
    peremption,
    unitesInitiales,
    unitesRestantes,
    statut,
    notes,
    ajouteePar,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoiteRow &&
          other.id == this.id &&
          other.officineId == this.officineId &&
          other.cip13 == this.cip13 &&
          other.lot == this.lot &&
          other.numeroSerie == this.numeroSerie &&
          other.peremption == this.peremption &&
          other.unitesInitiales == this.unitesInitiales &&
          other.unitesRestantes == this.unitesRestantes &&
          other.statut == this.statut &&
          other.notes == this.notes &&
          other.ajouteePar == this.ajouteePar &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class BoitesCompanion extends UpdateCompanion<BoiteRow> {
  final Value<String> id;
  final Value<String> officineId;
  final Value<String> cip13;
  final Value<String?> lot;
  final Value<String?> numeroSerie;
  final Value<String> peremption;
  final Value<int?> unitesInitiales;
  final Value<int?> unitesRestantes;
  final Value<String> statut;
  final Value<String?> notes;
  final Value<String> ajouteePar;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const BoitesCompanion({
    this.id = const Value.absent(),
    this.officineId = const Value.absent(),
    this.cip13 = const Value.absent(),
    this.lot = const Value.absent(),
    this.numeroSerie = const Value.absent(),
    this.peremption = const Value.absent(),
    this.unitesInitiales = const Value.absent(),
    this.unitesRestantes = const Value.absent(),
    this.statut = const Value.absent(),
    this.notes = const Value.absent(),
    this.ajouteePar = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoitesCompanion.insert({
    required String id,
    required String officineId,
    required String cip13,
    this.lot = const Value.absent(),
    this.numeroSerie = const Value.absent(),
    required String peremption,
    this.unitesInitiales = const Value.absent(),
    this.unitesRestantes = const Value.absent(),
    this.statut = const Value.absent(),
    this.notes = const Value.absent(),
    required String ajouteePar,
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       officineId = Value(officineId),
       cip13 = Value(cip13),
       peremption = Value(peremption),
       ajouteePar = Value(ajouteePar),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BoiteRow> custom({
    Expression<String>? id,
    Expression<String>? officineId,
    Expression<String>? cip13,
    Expression<String>? lot,
    Expression<String>? numeroSerie,
    Expression<String>? peremption,
    Expression<int>? unitesInitiales,
    Expression<int>? unitesRestantes,
    Expression<String>? statut,
    Expression<String>? notes,
    Expression<String>? ajouteePar,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (officineId != null) 'officine_id': officineId,
      if (cip13 != null) 'cip13': cip13,
      if (lot != null) 'lot': lot,
      if (numeroSerie != null) 'numero_serie': numeroSerie,
      if (peremption != null) 'peremption': peremption,
      if (unitesInitiales != null) 'unites_initiales': unitesInitiales,
      if (unitesRestantes != null) 'unites_restantes': unitesRestantes,
      if (statut != null) 'statut': statut,
      if (notes != null) 'notes': notes,
      if (ajouteePar != null) 'ajoutee_par': ajouteePar,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoitesCompanion copyWith({
    Value<String>? id,
    Value<String>? officineId,
    Value<String>? cip13,
    Value<String?>? lot,
    Value<String?>? numeroSerie,
    Value<String>? peremption,
    Value<int?>? unitesInitiales,
    Value<int?>? unitesRestantes,
    Value<String>? statut,
    Value<String?>? notes,
    Value<String>? ajouteePar,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return BoitesCompanion(
      id: id ?? this.id,
      officineId: officineId ?? this.officineId,
      cip13: cip13 ?? this.cip13,
      lot: lot ?? this.lot,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      peremption: peremption ?? this.peremption,
      unitesInitiales: unitesInitiales ?? this.unitesInitiales,
      unitesRestantes: unitesRestantes ?? this.unitesRestantes,
      statut: statut ?? this.statut,
      notes: notes ?? this.notes,
      ajouteePar: ajouteePar ?? this.ajouteePar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (officineId.present) {
      map['officine_id'] = Variable<String>(officineId.value);
    }
    if (cip13.present) {
      map['cip13'] = Variable<String>(cip13.value);
    }
    if (lot.present) {
      map['lot'] = Variable<String>(lot.value);
    }
    if (numeroSerie.present) {
      map['numero_serie'] = Variable<String>(numeroSerie.value);
    }
    if (peremption.present) {
      map['peremption'] = Variable<String>(peremption.value);
    }
    if (unitesInitiales.present) {
      map['unites_initiales'] = Variable<int>(unitesInitiales.value);
    }
    if (unitesRestantes.present) {
      map['unites_restantes'] = Variable<int>(unitesRestantes.value);
    }
    if (statut.present) {
      map['statut'] = Variable<String>(statut.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (ajouteePar.present) {
      map['ajoutee_par'] = Variable<String>(ajouteePar.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoitesCompanion(')
          ..write('id: $id, ')
          ..write('officineId: $officineId, ')
          ..write('cip13: $cip13, ')
          ..write('lot: $lot, ')
          ..write('numeroSerie: $numeroSerie, ')
          ..write('peremption: $peremption, ')
          ..write('unitesInitiales: $unitesInitiales, ')
          ..write('unitesRestantes: $unitesRestantes, ')
          ..write('statut: $statut, ')
          ..write('notes: $notes, ')
          ..write('ajouteePar: $ajouteePar, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrisesPlanifieesTable extends PrisesPlanifiees
    with TableInfo<$PrisesPlanifieesTable, PrisePlanifieeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrisesPlanifieesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prescriptionIdMeta = const VerificationMeta(
    'prescriptionId',
  );
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
    'prescription_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _officineIdMeta = const VerificationMeta(
    'officineId',
  );
  @override
  late final GeneratedColumn<String> officineId = GeneratedColumn<String>(
    'officine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datetimePrevueMeta = const VerificationMeta(
    'datetimePrevue',
  );
  @override
  late final GeneratedColumn<String> datetimePrevue = GeneratedColumn<String>(
    'datetime_prevue',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datetimeValidationMeta =
      const VerificationMeta('datetimeValidation');
  @override
  late final GeneratedColumn<String> datetimeValidation =
      GeneratedColumn<String>(
        'datetime_validation',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statutMeta = const VerificationMeta('statut');
  @override
  late final GeneratedColumn<String> statut = GeneratedColumn<String>(
    'statut',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('prevue'),
  );
  static const VerificationMeta _valideeParMeta = const VerificationMeta(
    'valideePar',
  );
  @override
  late final GeneratedColumn<String> valideePar = GeneratedColumn<String>(
    'validee_par',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    prescriptionId,
    officineId,
    datetimePrevue,
    datetimeValidation,
    statut,
    valideePar,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prises_planifiees';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrisePlanifieeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
        _prescriptionIdMeta,
        prescriptionId.isAcceptableOrUnknown(
          data['prescription_id']!,
          _prescriptionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prescriptionIdMeta);
    }
    if (data.containsKey('officine_id')) {
      context.handle(
        _officineIdMeta,
        officineId.isAcceptableOrUnknown(data['officine_id']!, _officineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_officineIdMeta);
    }
    if (data.containsKey('datetime_prevue')) {
      context.handle(
        _datetimePrevueMeta,
        datetimePrevue.isAcceptableOrUnknown(
          data['datetime_prevue']!,
          _datetimePrevueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_datetimePrevueMeta);
    }
    if (data.containsKey('datetime_validation')) {
      context.handle(
        _datetimeValidationMeta,
        datetimeValidation.isAcceptableOrUnknown(
          data['datetime_validation']!,
          _datetimeValidationMeta,
        ),
      );
    }
    if (data.containsKey('statut')) {
      context.handle(
        _statutMeta,
        statut.isAcceptableOrUnknown(data['statut']!, _statutMeta),
      );
    }
    if (data.containsKey('validee_par')) {
      context.handle(
        _valideeParMeta,
        valideePar.isAcceptableOrUnknown(data['validee_par']!, _valideeParMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrisePlanifieeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrisePlanifieeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      prescriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_id'],
      )!,
      officineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}officine_id'],
      )!,
      datetimePrevue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datetime_prevue'],
      )!,
      datetimeValidation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datetime_validation'],
      ),
      statut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statut'],
      )!,
      valideePar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}validee_par'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PrisesPlanifieesTable createAlias(String alias) {
    return $PrisesPlanifieesTable(attachedDatabase, alias);
  }
}

class PrisePlanifieeRow extends DataClass
    implements Insertable<PrisePlanifieeRow> {
  final String id;
  final String prescriptionId;
  final String officineId;
  final String datetimePrevue;
  final String? datetimeValidation;
  final String statut;
  final String? valideePar;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  const PrisePlanifieeRow({
    required this.id,
    required this.prescriptionId,
    required this.officineId,
    required this.datetimePrevue,
    this.datetimeValidation,
    required this.statut,
    this.valideePar,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['prescription_id'] = Variable<String>(prescriptionId);
    map['officine_id'] = Variable<String>(officineId);
    map['datetime_prevue'] = Variable<String>(datetimePrevue);
    if (!nullToAbsent || datetimeValidation != null) {
      map['datetime_validation'] = Variable<String>(datetimeValidation);
    }
    map['statut'] = Variable<String>(statut);
    if (!nullToAbsent || valideePar != null) {
      map['validee_par'] = Variable<String>(valideePar);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  PrisesPlanifieesCompanion toCompanion(bool nullToAbsent) {
    return PrisesPlanifieesCompanion(
      id: Value(id),
      prescriptionId: Value(prescriptionId),
      officineId: Value(officineId),
      datetimePrevue: Value(datetimePrevue),
      datetimeValidation: datetimeValidation == null && nullToAbsent
          ? const Value.absent()
          : Value(datetimeValidation),
      statut: Value(statut),
      valideePar: valideePar == null && nullToAbsent
          ? const Value.absent()
          : Value(valideePar),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PrisePlanifieeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrisePlanifieeRow(
      id: serializer.fromJson<String>(json['id']),
      prescriptionId: serializer.fromJson<String>(json['prescriptionId']),
      officineId: serializer.fromJson<String>(json['officineId']),
      datetimePrevue: serializer.fromJson<String>(json['datetimePrevue']),
      datetimeValidation: serializer.fromJson<String?>(
        json['datetimeValidation'],
      ),
      statut: serializer.fromJson<String>(json['statut']),
      valideePar: serializer.fromJson<String?>(json['valideePar']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'prescriptionId': serializer.toJson<String>(prescriptionId),
      'officineId': serializer.toJson<String>(officineId),
      'datetimePrevue': serializer.toJson<String>(datetimePrevue),
      'datetimeValidation': serializer.toJson<String?>(datetimeValidation),
      'statut': serializer.toJson<String>(statut),
      'valideePar': serializer.toJson<String?>(valideePar),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  PrisePlanifieeRow copyWith({
    String? id,
    String? prescriptionId,
    String? officineId,
    String? datetimePrevue,
    Value<String?> datetimeValidation = const Value.absent(),
    String? statut,
    Value<String?> valideePar = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => PrisePlanifieeRow(
    id: id ?? this.id,
    prescriptionId: prescriptionId ?? this.prescriptionId,
    officineId: officineId ?? this.officineId,
    datetimePrevue: datetimePrevue ?? this.datetimePrevue,
    datetimeValidation: datetimeValidation.present
        ? datetimeValidation.value
        : this.datetimeValidation,
    statut: statut ?? this.statut,
    valideePar: valideePar.present ? valideePar.value : this.valideePar,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PrisePlanifieeRow copyWithCompanion(PrisesPlanifieesCompanion data) {
    return PrisePlanifieeRow(
      id: data.id.present ? data.id.value : this.id,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      officineId: data.officineId.present
          ? data.officineId.value
          : this.officineId,
      datetimePrevue: data.datetimePrevue.present
          ? data.datetimePrevue.value
          : this.datetimePrevue,
      datetimeValidation: data.datetimeValidation.present
          ? data.datetimeValidation.value
          : this.datetimeValidation,
      statut: data.statut.present ? data.statut.value : this.statut,
      valideePar: data.valideePar.present
          ? data.valideePar.value
          : this.valideePar,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrisePlanifieeRow(')
          ..write('id: $id, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('officineId: $officineId, ')
          ..write('datetimePrevue: $datetimePrevue, ')
          ..write('datetimeValidation: $datetimeValidation, ')
          ..write('statut: $statut, ')
          ..write('valideePar: $valideePar, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    prescriptionId,
    officineId,
    datetimePrevue,
    datetimeValidation,
    statut,
    valideePar,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrisePlanifieeRow &&
          other.id == this.id &&
          other.prescriptionId == this.prescriptionId &&
          other.officineId == this.officineId &&
          other.datetimePrevue == this.datetimePrevue &&
          other.datetimeValidation == this.datetimeValidation &&
          other.statut == this.statut &&
          other.valideePar == this.valideePar &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PrisesPlanifieesCompanion extends UpdateCompanion<PrisePlanifieeRow> {
  final Value<String> id;
  final Value<String> prescriptionId;
  final Value<String> officineId;
  final Value<String> datetimePrevue;
  final Value<String?> datetimeValidation;
  final Value<String> statut;
  final Value<String?> valideePar;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const PrisesPlanifieesCompanion({
    this.id = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.officineId = const Value.absent(),
    this.datetimePrevue = const Value.absent(),
    this.datetimeValidation = const Value.absent(),
    this.statut = const Value.absent(),
    this.valideePar = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrisesPlanifieesCompanion.insert({
    required String id,
    required String prescriptionId,
    required String officineId,
    required String datetimePrevue,
    this.datetimeValidation = const Value.absent(),
    this.statut = const Value.absent(),
    this.valideePar = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       prescriptionId = Value(prescriptionId),
       officineId = Value(officineId),
       datetimePrevue = Value(datetimePrevue),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PrisePlanifieeRow> custom({
    Expression<String>? id,
    Expression<String>? prescriptionId,
    Expression<String>? officineId,
    Expression<String>? datetimePrevue,
    Expression<String>? datetimeValidation,
    Expression<String>? statut,
    Expression<String>? valideePar,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (officineId != null) 'officine_id': officineId,
      if (datetimePrevue != null) 'datetime_prevue': datetimePrevue,
      if (datetimeValidation != null) 'datetime_validation': datetimeValidation,
      if (statut != null) 'statut': statut,
      if (valideePar != null) 'validee_par': valideePar,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrisesPlanifieesCompanion copyWith({
    Value<String>? id,
    Value<String>? prescriptionId,
    Value<String>? officineId,
    Value<String>? datetimePrevue,
    Value<String?>? datetimeValidation,
    Value<String>? statut,
    Value<String?>? valideePar,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PrisesPlanifieesCompanion(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      officineId: officineId ?? this.officineId,
      datetimePrevue: datetimePrevue ?? this.datetimePrevue,
      datetimeValidation: datetimeValidation ?? this.datetimeValidation,
      statut: statut ?? this.statut,
      valideePar: valideePar ?? this.valideePar,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (officineId.present) {
      map['officine_id'] = Variable<String>(officineId.value);
    }
    if (datetimePrevue.present) {
      map['datetime_prevue'] = Variable<String>(datetimePrevue.value);
    }
    if (datetimeValidation.present) {
      map['datetime_validation'] = Variable<String>(datetimeValidation.value);
    }
    if (statut.present) {
      map['statut'] = Variable<String>(statut.value);
    }
    if (valideePar.present) {
      map['validee_par'] = Variable<String>(valideePar.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrisesPlanifieesCompanion(')
          ..write('id: $id, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('officineId: $officineId, ')
          ..write('datetimePrevue: $datetimePrevue, ')
          ..write('datetimeValidation: $datetimeValidation, ')
          ..write('statut: $statut, ')
          ..write('valideePar: $valideePar, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOperationsTable extends PendingOperations
    with TableInfo<$PendingOperationsTable, PendingOperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampLocalMeta = const VerificationMeta(
    'timestampLocal',
  );
  @override
  late final GeneratedColumn<int> timestampLocal = GeneratedColumn<int>(
    'timestamp_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statutMeta = const VerificationMeta('statut');
  @override
  late final GeneratedColumn<String> statut = GeneratedColumn<String>(
    'statut',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    entityType,
    entityId,
    payload,
    timestampLocal,
    statut,
    retryCount,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('timestamp_local')) {
      context.handle(
        _timestampLocalMeta,
        timestampLocal.isAcceptableOrUnknown(
          data['timestamp_local']!,
          _timestampLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampLocalMeta);
    }
    if (data.containsKey('statut')) {
      context.handle(
        _statutMeta,
        statut.isAcceptableOrUnknown(data['statut']!, _statutMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOperationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      timestampLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_local'],
      )!,
      statut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statut'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingOperationsTable createAlias(String alias) {
    return $PendingOperationsTable(attachedDatabase, alias);
  }
}

class PendingOperationRow extends DataClass
    implements Insertable<PendingOperationRow> {
  final String id;
  final String type;
  final String entityType;
  final String entityId;
  final String payload;
  final int timestampLocal;
  final String statut;
  final int retryCount;
  final String? lastError;
  final String createdAt;
  final String updatedAt;
  const PendingOperationRow({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.timestampLocal,
    required this.statut,
    required this.retryCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['timestamp_local'] = Variable<int>(timestampLocal);
    map['statut'] = Variable<String>(statut);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PendingOperationsCompanion toCompanion(bool nullToAbsent) {
    return PendingOperationsCompanion(
      id: Value(id),
      type: Value(type),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payload: Value(payload),
      timestampLocal: Value(timestampLocal),
      statut: Value(statut),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOperationRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      timestampLocal: serializer.fromJson<int>(json['timestampLocal']),
      statut: serializer.fromJson<String>(json['statut']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'timestampLocal': serializer.toJson<int>(timestampLocal),
      'statut': serializer.toJson<String>(statut),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  PendingOperationRow copyWith({
    String? id,
    String? type,
    String? entityType,
    String? entityId,
    String? payload,
    int? timestampLocal,
    String? statut,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => PendingOperationRow(
    id: id ?? this.id,
    type: type ?? this.type,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    timestampLocal: timestampLocal ?? this.timestampLocal,
    statut: statut ?? this.statut,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingOperationRow copyWithCompanion(PendingOperationsCompanion data) {
    return PendingOperationRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      timestampLocal: data.timestampLocal.present
          ? data.timestampLocal.value
          : this.timestampLocal,
      statut: data.statut.present ? data.statut.value : this.statut,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('timestampLocal: $timestampLocal, ')
          ..write('statut: $statut, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    entityType,
    entityId,
    payload,
    timestampLocal,
    statut,
    retryCount,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOperationRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.timestampLocal == this.timestampLocal &&
          other.statut == this.statut &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingOperationsCompanion extends UpdateCompanion<PendingOperationRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<int> timestampLocal;
  final Value<String> statut;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PendingOperationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.timestampLocal = const Value.absent(),
    this.statut = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingOperationsCompanion.insert({
    required String id,
    required String type,
    required String entityType,
    required String entityId,
    required String payload,
    required int timestampLocal,
    this.statut = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       entityType = Value(entityType),
       entityId = Value(entityId),
       payload = Value(payload),
       timestampLocal = Value(timestampLocal),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingOperationRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<int>? timestampLocal,
    Expression<String>? statut,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (timestampLocal != null) 'timestamp_local': timestampLocal,
      if (statut != null) 'statut': statut,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingOperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? payload,
    Value<int>? timestampLocal,
    Value<String>? statut,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingOperationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      timestampLocal: timestampLocal ?? this.timestampLocal,
      statut: statut ?? this.statut,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (timestampLocal.present) {
      map['timestamp_local'] = Variable<int>(timestampLocal.value);
    }
    if (statut.present) {
      map['statut'] = Variable<String>(statut.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('timestampLocal: $timestampLocal, ')
          ..write('statut: $statut, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $BoitesTable boites = $BoitesTable(this);
  late final $PrisesPlanifieesTable prisesPlanifiees = $PrisesPlanifieesTable(
    this,
  );
  late final $PendingOperationsTable pendingOperations =
      $PendingOperationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    boites,
    prisesPlanifiees,
    pendingOperations,
  ];
}

typedef $$BoitesTableCreateCompanionBuilder =
    BoitesCompanion Function({
      required String id,
      required String officineId,
      required String cip13,
      Value<String?> lot,
      Value<String?> numeroSerie,
      required String peremption,
      Value<int?> unitesInitiales,
      Value<int?> unitesRestantes,
      Value<String> statut,
      Value<String?> notes,
      required String ajouteePar,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$BoitesTableUpdateCompanionBuilder =
    BoitesCompanion Function({
      Value<String> id,
      Value<String> officineId,
      Value<String> cip13,
      Value<String?> lot,
      Value<String?> numeroSerie,
      Value<String> peremption,
      Value<int?> unitesInitiales,
      Value<int?> unitesRestantes,
      Value<String> statut,
      Value<String?> notes,
      Value<String> ajouteePar,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$BoitesTableFilterComposer
    extends Composer<_$LocalDatabase, $BoitesTable> {
  $$BoitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officineId => $composableBuilder(
    column: $table.officineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cip13 => $composableBuilder(
    column: $table.cip13,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lot => $composableBuilder(
    column: $table.lot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get numeroSerie => $composableBuilder(
    column: $table.numeroSerie,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peremption => $composableBuilder(
    column: $table.peremption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitesInitiales => $composableBuilder(
    column: $table.unitesInitiales,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitesRestantes => $composableBuilder(
    column: $table.unitesRestantes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ajouteePar => $composableBuilder(
    column: $table.ajouteePar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BoitesTableOrderingComposer
    extends Composer<_$LocalDatabase, $BoitesTable> {
  $$BoitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officineId => $composableBuilder(
    column: $table.officineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cip13 => $composableBuilder(
    column: $table.cip13,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lot => $composableBuilder(
    column: $table.lot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numeroSerie => $composableBuilder(
    column: $table.numeroSerie,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peremption => $composableBuilder(
    column: $table.peremption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitesInitiales => $composableBuilder(
    column: $table.unitesInitiales,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitesRestantes => $composableBuilder(
    column: $table.unitesRestantes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ajouteePar => $composableBuilder(
    column: $table.ajouteePar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BoitesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $BoitesTable> {
  $$BoitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get officineId => $composableBuilder(
    column: $table.officineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cip13 =>
      $composableBuilder(column: $table.cip13, builder: (column) => column);

  GeneratedColumn<String> get lot =>
      $composableBuilder(column: $table.lot, builder: (column) => column);

  GeneratedColumn<String> get numeroSerie => $composableBuilder(
    column: $table.numeroSerie,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peremption => $composableBuilder(
    column: $table.peremption,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitesInitiales => $composableBuilder(
    column: $table.unitesInitiales,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitesRestantes => $composableBuilder(
    column: $table.unitesRestantes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statut =>
      $composableBuilder(column: $table.statut, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get ajouteePar => $composableBuilder(
    column: $table.ajouteePar,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$BoitesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $BoitesTable,
          BoiteRow,
          $$BoitesTableFilterComposer,
          $$BoitesTableOrderingComposer,
          $$BoitesTableAnnotationComposer,
          $$BoitesTableCreateCompanionBuilder,
          $$BoitesTableUpdateCompanionBuilder,
          (BoiteRow, BaseReferences<_$LocalDatabase, $BoitesTable, BoiteRow>),
          BoiteRow,
          PrefetchHooks Function()
        > {
  $$BoitesTableTableManager(_$LocalDatabase db, $BoitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> officineId = const Value.absent(),
                Value<String> cip13 = const Value.absent(),
                Value<String?> lot = const Value.absent(),
                Value<String?> numeroSerie = const Value.absent(),
                Value<String> peremption = const Value.absent(),
                Value<int?> unitesInitiales = const Value.absent(),
                Value<int?> unitesRestantes = const Value.absent(),
                Value<String> statut = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> ajouteePar = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoitesCompanion(
                id: id,
                officineId: officineId,
                cip13: cip13,
                lot: lot,
                numeroSerie: numeroSerie,
                peremption: peremption,
                unitesInitiales: unitesInitiales,
                unitesRestantes: unitesRestantes,
                statut: statut,
                notes: notes,
                ajouteePar: ajouteePar,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String officineId,
                required String cip13,
                Value<String?> lot = const Value.absent(),
                Value<String?> numeroSerie = const Value.absent(),
                required String peremption,
                Value<int?> unitesInitiales = const Value.absent(),
                Value<int?> unitesRestantes = const Value.absent(),
                Value<String> statut = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String ajouteePar,
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoitesCompanion.insert(
                id: id,
                officineId: officineId,
                cip13: cip13,
                lot: lot,
                numeroSerie: numeroSerie,
                peremption: peremption,
                unitesInitiales: unitesInitiales,
                unitesRestantes: unitesRestantes,
                statut: statut,
                notes: notes,
                ajouteePar: ajouteePar,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BoitesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $BoitesTable,
      BoiteRow,
      $$BoitesTableFilterComposer,
      $$BoitesTableOrderingComposer,
      $$BoitesTableAnnotationComposer,
      $$BoitesTableCreateCompanionBuilder,
      $$BoitesTableUpdateCompanionBuilder,
      (BoiteRow, BaseReferences<_$LocalDatabase, $BoitesTable, BoiteRow>),
      BoiteRow,
      PrefetchHooks Function()
    >;
typedef $$PrisesPlanifieesTableCreateCompanionBuilder =
    PrisesPlanifieesCompanion Function({
      required String id,
      required String prescriptionId,
      required String officineId,
      required String datetimePrevue,
      Value<String?> datetimeValidation,
      Value<String> statut,
      Value<String?> valideePar,
      Value<String?> notes,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$PrisesPlanifieesTableUpdateCompanionBuilder =
    PrisesPlanifieesCompanion Function({
      Value<String> id,
      Value<String> prescriptionId,
      Value<String> officineId,
      Value<String> datetimePrevue,
      Value<String?> datetimeValidation,
      Value<String> statut,
      Value<String?> valideePar,
      Value<String?> notes,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$PrisesPlanifieesTableFilterComposer
    extends Composer<_$LocalDatabase, $PrisesPlanifieesTable> {
  $$PrisesPlanifieesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officineId => $composableBuilder(
    column: $table.officineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datetimePrevue => $composableBuilder(
    column: $table.datetimePrevue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datetimeValidation => $composableBuilder(
    column: $table.datetimeValidation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valideePar => $composableBuilder(
    column: $table.valideePar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrisesPlanifieesTableOrderingComposer
    extends Composer<_$LocalDatabase, $PrisesPlanifieesTable> {
  $$PrisesPlanifieesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officineId => $composableBuilder(
    column: $table.officineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datetimePrevue => $composableBuilder(
    column: $table.datetimePrevue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datetimeValidation => $composableBuilder(
    column: $table.datetimeValidation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valideePar => $composableBuilder(
    column: $table.valideePar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrisesPlanifieesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PrisesPlanifieesTable> {
  $$PrisesPlanifieesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get officineId => $composableBuilder(
    column: $table.officineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datetimePrevue => $composableBuilder(
    column: $table.datetimePrevue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datetimeValidation => $composableBuilder(
    column: $table.datetimeValidation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statut =>
      $composableBuilder(column: $table.statut, builder: (column) => column);

  GeneratedColumn<String> get valideePar => $composableBuilder(
    column: $table.valideePar,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PrisesPlanifieesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $PrisesPlanifieesTable,
          PrisePlanifieeRow,
          $$PrisesPlanifieesTableFilterComposer,
          $$PrisesPlanifieesTableOrderingComposer,
          $$PrisesPlanifieesTableAnnotationComposer,
          $$PrisesPlanifieesTableCreateCompanionBuilder,
          $$PrisesPlanifieesTableUpdateCompanionBuilder,
          (
            PrisePlanifieeRow,
            BaseReferences<
              _$LocalDatabase,
              $PrisesPlanifieesTable,
              PrisePlanifieeRow
            >,
          ),
          PrisePlanifieeRow,
          PrefetchHooks Function()
        > {
  $$PrisesPlanifieesTableTableManager(
    _$LocalDatabase db,
    $PrisesPlanifieesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrisesPlanifieesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrisesPlanifieesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrisesPlanifieesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> prescriptionId = const Value.absent(),
                Value<String> officineId = const Value.absent(),
                Value<String> datetimePrevue = const Value.absent(),
                Value<String?> datetimeValidation = const Value.absent(),
                Value<String> statut = const Value.absent(),
                Value<String?> valideePar = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrisesPlanifieesCompanion(
                id: id,
                prescriptionId: prescriptionId,
                officineId: officineId,
                datetimePrevue: datetimePrevue,
                datetimeValidation: datetimeValidation,
                statut: statut,
                valideePar: valideePar,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String prescriptionId,
                required String officineId,
                required String datetimePrevue,
                Value<String?> datetimeValidation = const Value.absent(),
                Value<String> statut = const Value.absent(),
                Value<String?> valideePar = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrisesPlanifieesCompanion.insert(
                id: id,
                prescriptionId: prescriptionId,
                officineId: officineId,
                datetimePrevue: datetimePrevue,
                datetimeValidation: datetimeValidation,
                statut: statut,
                valideePar: valideePar,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrisesPlanifieesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $PrisesPlanifieesTable,
      PrisePlanifieeRow,
      $$PrisesPlanifieesTableFilterComposer,
      $$PrisesPlanifieesTableOrderingComposer,
      $$PrisesPlanifieesTableAnnotationComposer,
      $$PrisesPlanifieesTableCreateCompanionBuilder,
      $$PrisesPlanifieesTableUpdateCompanionBuilder,
      (
        PrisePlanifieeRow,
        BaseReferences<
          _$LocalDatabase,
          $PrisesPlanifieesTable,
          PrisePlanifieeRow
        >,
      ),
      PrisePlanifieeRow,
      PrefetchHooks Function()
    >;
typedef $$PendingOperationsTableCreateCompanionBuilder =
    PendingOperationsCompanion Function({
      required String id,
      required String type,
      required String entityType,
      required String entityId,
      required String payload,
      required int timestampLocal,
      Value<String> statut,
      Value<int> retryCount,
      Value<String?> lastError,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$PendingOperationsTableUpdateCompanionBuilder =
    PendingOperationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> payload,
      Value<int> timestampLocal,
      Value<String> statut,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$PendingOperationsTableFilterComposer
    extends Composer<_$LocalDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampLocal => $composableBuilder(
    column: $table.timestampLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOperationsTableOrderingComposer
    extends Composer<_$LocalDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampLocal => $composableBuilder(
    column: $table.timestampLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOperationsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get timestampLocal => $composableBuilder(
    column: $table.timestampLocal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statut =>
      $composableBuilder(column: $table.statut, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingOperationsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $PendingOperationsTable,
          PendingOperationRow,
          $$PendingOperationsTableFilterComposer,
          $$PendingOperationsTableOrderingComposer,
          $$PendingOperationsTableAnnotationComposer,
          $$PendingOperationsTableCreateCompanionBuilder,
          $$PendingOperationsTableUpdateCompanionBuilder,
          (
            PendingOperationRow,
            BaseReferences<
              _$LocalDatabase,
              $PendingOperationsTable,
              PendingOperationRow
            >,
          ),
          PendingOperationRow,
          PrefetchHooks Function()
        > {
  $$PendingOperationsTableTableManager(
    _$LocalDatabase db,
    $PendingOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> timestampLocal = const Value.absent(),
                Value<String> statut = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingOperationsCompanion(
                id: id,
                type: type,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                timestampLocal: timestampLocal,
                statut: statut,
                retryCount: retryCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String entityType,
                required String entityId,
                required String payload,
                required int timestampLocal,
                Value<String> statut = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingOperationsCompanion.insert(
                id: id,
                type: type,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                timestampLocal: timestampLocal,
                statut: statut,
                retryCount: retryCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $PendingOperationsTable,
      PendingOperationRow,
      $$PendingOperationsTableFilterComposer,
      $$PendingOperationsTableOrderingComposer,
      $$PendingOperationsTableAnnotationComposer,
      $$PendingOperationsTableCreateCompanionBuilder,
      $$PendingOperationsTableUpdateCompanionBuilder,
      (
        PendingOperationRow,
        BaseReferences<
          _$LocalDatabase,
          $PendingOperationsTable,
          PendingOperationRow
        >,
      ),
      PendingOperationRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$BoitesTableTableManager get boites =>
      $$BoitesTableTableManager(_db, _db.boites);
  $$PrisesPlanifieesTableTableManager get prisesPlanifiees =>
      $$PrisesPlanifieesTableTableManager(_db, _db.prisesPlanifiees);
  $$PendingOperationsTableTableManager get pendingOperations =>
      $$PendingOperationsTableTableManager(_db, _db.pendingOperations);
}
