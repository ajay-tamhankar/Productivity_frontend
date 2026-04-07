import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/production_entry_model.dart';
import 'report_export_service.dart';
import 'reports_provider.dart';

class ReportsListScreen extends StatelessWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const reports = <_ReportMeta>[
      _ReportMeta(
        title: 'Daily Production',
        subtitle: 'Day-wise output and quality insight',
        icon: Icons.today_outlined,
        accent: Color(0xFF1565C0),
      ),
      _ReportMeta(
        title: 'Shift Performance',
        subtitle: 'Compare Shift A/B/C productivity',
        icon: Icons.schedule_outlined,
        accent: Color(0xFF2E7D32),
      ),
      _ReportMeta(
        title: 'Operator Performance',
        subtitle: 'Review operator-level throughput',
        icon: Icons.groups_2_outlined,
        accent: Color(0xFF6A1B9A),
      ),
      _ReportMeta(
        title: 'Machine Performance',
        subtitle: 'Machine efficiency and quality trends',
        icon: Icons.precision_manufacturing_outlined,
        accent: Color(0xFFEF6C00),
      ),
      _ReportMeta(
        title: 'Rejection Analysis',
        subtitle: 'Find top rejection reasons quickly',
        icon: Icons.rule_folder_outlined,
        accent: Color(0xFFC62828),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports Hub')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F9FF), Color(0xFFF0FFF8), Color(0xFFF7F3FF)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          children: [
            _ReportsHero(reportCount: reports.length),
            const SizedBox(height: 16),
            ...reports.map(
              (meta) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReportCard(
                  meta: meta,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailScreen(reportName: meta.title),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportDetailScreen extends ConsumerStatefulWidget {
  final String reportName;
  const ReportDetailScreen({super.key, required this.reportName});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  static const int _rowsPerPage = 10;
  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _countFormat = NumberFormat.decimalPattern();
  String _statusFilter = 'ALL';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _applyFiltersAndLoad(0));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int pageIndex) async {
    await ref.read(reportsControllerProvider.notifier).fetchPage(
          pageIndex,
          _rowsPerPage,
        );
  }

  DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);
  DateTime _endOfDay(DateTime value) => DateTime(value.year, value.month, value.day, 23, 59, 59);

  Map<String, dynamic> _buildApiFilters() {
    final filters = <String, dynamic>{};
    if (_fromDate != null) {
      filters['fromDate'] = DateFormat('yyyy-MM-dd').format(_fromDate!);
    }
    if (_toDate != null) {
      filters['toDate'] = DateFormat('yyyy-MM-dd').format(_toDate!);
    }
    return filters;
  }

  Future<void> _applyFiltersAndLoad(int pageIndex) async {
    ref.read(reportsControllerProvider.notifier).updateFilters(_buildApiFilters());
    await _loadPage(pageIndex);
  }

  String _formatError(Object error) {
    final raw = error.toString();
    const prefix = 'Exception:';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length).trim();
    }
    return raw;
  }

  String _safeText(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return _safeText(rawDate);
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  List<ProductionEntryModel> _filtered(List<ProductionEntryModel> source) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return source.where((entry) {
      final status = (entry.approvalStatus ?? 'PENDING').trim().toUpperCase();
      if (_statusFilter != 'ALL' && status != _statusFilter) return false;

      final entryDate = DateTime.tryParse(entry.entryDate);
      if (_fromDate != null && entryDate != null && entryDate.isBefore(_startOfDay(_fromDate!))) {
        return false;
      }
      if (_toDate != null && entryDate != null && entryDate.isAfter(_endOfDay(_toDate!))) {
        return false;
      }

      if (query.isEmpty) return true;

      final machine = (entry.machineName ?? entry.machineId).toLowerCase();
      final item = (entry.itemDescription ?? entry.itemId).toLowerCase();
      return machine.contains(query) ||
          item.contains(query) ||
          entry.shift.toLowerCase().contains(query) ||
          status.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? _toDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
    });
    await _applyFiltersAndLoad(0);
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _toDate = picked;
      if (_fromDate != null && _fromDate!.isAfter(picked)) {
        _fromDate = picked;
      }
    });
    await _applyFiltersAndLoad(0);
  }

  Future<void> _clearDateFilter() async {
    if (_fromDate == null && _toDate == null) return;
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    await _applyFiltersAndLoad(0);
  }

  Future<void> _submitUpdate({
    required int pageIndex,
    required String entryId,
    required Map<String, dynamic> payload,
    required String successMessage,
  }) async {
    try {
      await ref.read(reportsControllerProvider.notifier).updateEntry(
            id: entryId,
            payload: payload,
          );
      await _applyFiltersAndLoad(pageIndex);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_formatError(e))));
    }
  }

  Future<void> _handleReportFileAction(
    _ReportFileAction action,
    List<ProductionEntryModel> currentEntries,
  ) async {
    if (currentEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final isExcel = action == _ReportFileAction.downloadExcel ||
          action == _ReportFileAction.shareExcel;
      final isShare = action == _ReportFileAction.shareExcel ||
          action == _ReportFileAction.sharePdf;

      String? path;
      if (isShare) {
        if (isExcel) {
          await ReportExportService.shareExcel(
            reportName: widget.reportName,
            entries: currentEntries,
          );
        } else {
          await ReportExportService.sharePdf(
            reportName: widget.reportName,
            entries: currentEntries,
          );
        }
      } else {
        if (isExcel) {
          path = await ReportExportService.exportExcel(
            reportName: widget.reportName,
            entries: currentEntries,
          );
        } else {
          path = await ReportExportService.exportPdf(
            reportName: widget.reportName,
            entries: currentEntries,
          );
        }
      }

      if (!mounted) return;
      final exportedName = isExcel ? 'Excel' : 'PDF';
      final message = isShare
          ? '$exportedName share opened.'
          : (path == null
                ? '$exportedName download started.'
                : '$exportedName exported to: $path');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleAction(
    ProductionEntryModel entry,
    _RowAction action,
    int pageIndex,
  ) async {
    final id = entry.id?.trim() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot update entry without ID.')),
      );
      return;
    }

    switch (action) {
      case _RowAction.approve:
        await _submitUpdate(
          pageIndex: pageIndex,
          entryId: id,
          payload: const {'approvalStatus': 'APPROVED'},
          successMessage: 'Entry approved.',
        );
        break;
      case _RowAction.reject:
        await _submitUpdate(
          pageIndex: pageIndex,
          entryId: id,
          payload: const {'approvalStatus': 'REJECTED'},
          successMessage: 'Entry rejected.',
        );
        break;
      case _RowAction.pending:
        await _submitUpdate(
          pageIndex: pageIndex,
          entryId: id,
          payload: const {'approvalStatus': 'PENDING'},
          successMessage: 'Entry set to pending.',
        );
        break;
      case _RowAction.edit:
        final payload = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _EntryEditDialog(entry: entry),
        );
        if (payload == null || payload.isEmpty) return;
        await _submitUpdate(
          pageIndex: pageIndex,
          entryId: id,
          payload: payload,
          successMessage: 'Entry updated.',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);
    final entries = _filtered(state.entries);

    final approved = entries
        .where((e) => (e.approvalStatus ?? 'PENDING').toUpperCase() == 'APPROVED')
        .length;
    final rejected = entries
        .where((e) => (e.approvalStatus ?? 'PENDING').toUpperCase() == 'REJECTED')
        .length;
    final qty = entries.fold<int>(0, (sum, e) => sum + e.actualQuantity);

    final totalPages =
        state.totalCount == 0 ? 1 : ((state.totalCount + _rowsPerPage - 1) ~/ _rowsPerPage);
    final canGoPrev = state.currentPage > 0;
    final canGoNext = state.currentPage + 1 < totalPages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportName),
        actions: [
          PopupMenuButton<_ReportFileAction>(
            tooltip: 'Download / Share',
            icon: const Icon(Icons.download_outlined),
            onSelected: (value) => _handleReportFileAction(value, entries),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ReportFileAction.downloadExcel,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.table_view_outlined),
                  title: Text('Download Excel'),
                ),
              ),
              PopupMenuItem(
                value: _ReportFileAction.downloadPdf,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Download PDF'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _ReportFileAction.shareExcel,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.ios_share_outlined),
                  title: Text('Share Excel'),
                ),
              ),
              PopupMenuItem(
                value: _ReportFileAction.sharePdf,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.share_outlined),
                  title: Text('Share PDF'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _applyFiltersAndLoad(state.currentPage),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFF2FFF9), Color(0xFFF7F2FF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => _applyFiltersAndLoad(state.currentPage),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ReportHeader(reportName: widget.reportName),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatCard(title: 'Records', value: _countFormat.format(entries.length)),
                  _StatCard(title: 'Approved', value: _countFormat.format(approved)),
                  _StatCard(title: 'Rejected', value: _countFormat.format(rejected)),
                  _StatCard(title: 'Total Qty', value: _countFormat.format(qty)),
                ],
              ),
              const SizedBox(height: 12),
              _FilterPanel(
                searchCtrl: _searchCtrl,
                statusFilter: _statusFilter,
                onQuery: (_) => setState(() {}),
                onStatus: (value) => setState(() => _statusFilter = value),
                fromDate: _fromDate,
                toDate: _toDate,
                onPickFromDate: _pickFromDate,
                onPickToDate: _pickToDate,
                onClearDateFilter: _clearDateFilter,
              ),
              const SizedBox(height: 12),
              if (state.isLoading && state.entries.isEmpty)
                const _StateCard(title: 'Loading entries...', subtitle: 'Fetching latest records.')
              else if (entries.isEmpty)
                const _StateCard(
                  title: 'No entries found',
                  subtitle: 'Try changing search or status filter.',
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EAF6)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 92,
                      horizontalMargin: 10,
                      columnSpacing: 14,
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFFF3F8FF),
                      ),
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Shift')),
                        DataColumn(label: Text('Operator')),
                        DataColumn(label: Text('Machine')),
                        DataColumn(label: Text('RC Number')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Actual')),
                        DataColumn(label: Text('Reject')),
                        DataColumn(label: Text('Weight (KG)')),
                        DataColumn(label: Text('Parts/Hr')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: entries.map((entry) {
                        final status = _safeText(entry.approvalStatus ?? 'PENDING').toUpperCase();
                        final machine = _safeText(entry.machineName ?? entry.machineId);
                        final rcNumber = _safeText(entry.rcNumber);
                        final item = _safeText(entry.itemDescription ?? entry.itemId);

                        return DataRow(
                          cells: [
                            DataCell(Text(_formatDate(entry.entryDate))),
                            DataCell(Text(_safeText(entry.shift))),
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: Text(
                                  _safeText(entry.operatorName ?? entry.operatorId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  machine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(
                                  rcNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 210,
                                child: Text(
                                  item,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(entry.actualQuantity.toString())),
                            DataCell(Text(entry.rejectionQuantity.toString())),
                            DataCell(Text(entry.weightInKGs.toStringAsFixed(2))),
                            DataCell(Text(entry.partsPerHour.toStringAsFixed(1))),
                            DataCell(_StatusPill(status: status)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _Pager(
                currentPage: state.currentPage,
                totalPages: totalPages,
                totalRecords: state.totalCount,
                canGoPrev: canGoPrev,
                canGoNext: canGoNext,
                onPrev: canGoPrev ? () => _applyFiltersAndLoad(state.currentPage - 1) : null,
                onNext: canGoNext ? () => _applyFiltersAndLoad(state.currentPage + 1) : null,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          (state.isLoading || _isExporting) ? const LinearProgressIndicator(minHeight: 2) : null,
    );
  }
}

enum _RowAction { edit, approve, reject, pending }
enum _ReportFileAction { downloadExcel, downloadPdf, shareExcel, sharePdf }

class _ReportMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _ReportMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

class _ReportsHero extends StatelessWidget {
  final int reportCount;
  const _ReportsHero({required this.reportCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF133F8A), Color(0xFF1A7C89), Color(0xFF3A9B73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports Command Center',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore $reportCount report views with cleaner insights and faster actions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportMeta meta;
  final VoidCallback onTap;
  const _ReportCard({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2EAF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: meta.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(meta.icon, color: meta.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(meta.subtitle, style: const TextStyle(color: Color(0xFF5D6A7A))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  final String reportName;

  const _ReportHeader({
    required this.reportName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF185ADB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insights_outlined, color: Color(0xFF185ADB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  'Read-only report insights. Use Review Actions tab for approval workflow.',
                  style: const TextStyle(color: Color(0xFF5D6A7A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF617286), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String statusFilter;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onStatus;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onClearDateFilter;

  const _FilterPanel({
    required this.searchCtrl,
    required this.statusFilter,
    required this.onQuery,
    required this.onStatus,
    required this.fromDate,
    required this.toDate,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onClearDateFilter,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = ['ALL', 'APPROVED', 'REJECTED', 'PENDING'];
    final hasDateFilter = fromDate != null || toDate != null;
    final dateFormat = DateFormat('dd MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onQuery,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search machine, item, shift, status',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  value: statusFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: statuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    onStatus(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPickFromDate,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  fromDate == null ? 'From Date' : 'From: ${dateFormat.format(fromDate!)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickToDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  toDate == null ? 'To Date' : 'To: ${dateFormat.format(toDate!)}',
                ),
              ),
              if (hasDateFilter)
                TextButton.icon(
                  onPressed: onClearDateFilter,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Date Filter'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StateCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF5D6A7A))),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final ProductionEntryModel entry;
  final bool canManage;
  final ValueChanged<_RowAction> onAction;

  const _EntryCard({
    required this.entry,
    required this.canManage,
    required this.onAction,
  });

  String _safeText(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return _safeText(rawDate);
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final status = _safeText(entry.approvalStatus ?? 'PENDING').toUpperCase();
    final machine = _safeText(entry.machineName ?? entry.machineId);
    final item = _safeText(entry.itemDescription ?? entry.itemId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$machine | $item',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Date: ${_formatDate(entry.entryDate)} | Shift: ${_safeText(entry.shift)}',
            style: const TextStyle(color: Color(0xFF5D6A7A)),
          ),
          const SizedBox(height: 3),
          Text(
            'Operator: ${_safeText(entry.operatorName ?? entry.operatorId)} | RC: ${_safeText(entry.rcNumber)}',
            style: const TextStyle(color: Color(0xFF5D6A7A)),
          ),
          const SizedBox(height: 3),
          Text(
            'Actual: ${entry.actualQuantity} | Reject: ${entry.rejectionQuantity} | Parts/Hr: ${entry.partsPerHour.toStringAsFixed(1)}',
            style: const TextStyle(color: Color(0xFF5D6A7A)),
          ),
          if ((entry.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Note: ${entry.notes!.trim()}', style: const TextStyle(color: Color(0xFF5D6A7A))),
          ],
          if (canManage) ...[
            const SizedBox(height: 10),
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Color(0xFF4C596A),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EntryActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF185ADB),
                  onTap: () => onAction(_RowAction.edit),
                ),
                _EntryActionButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF127944),
                  onTap: () => onAction(_RowAction.approve),
                ),
                _EntryActionButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFB32929),
                  onTap: () => onAction(_RowAction.reject),
                ),
                _EntryActionButton(
                  label: 'Pending',
                  icon: Icons.schedule_outlined,
                  color: const Color(0xFF8D5A00),
                  onTap: () => onAction(_RowAction.pending),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EntryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    if (status == 'APPROVED') {
      bgColor = const Color(0xFFE7F8EF);
      textColor = const Color(0xFF127944);
    } else if (status == 'REJECTED') {
      bgColor = const Color(0xFFFFEAEA);
      textColor = const Color(0xFFB32929);
    } else {
      bgColor = const Color(0xFFFFF6E2);
      textColor = const Color(0xFF8D5A00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _Pager({
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;
          if (!isCompact) {
            return Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                const Spacer(),
                Text(
                  'Page ${currentPage + 1} / $totalPages | $totalRecords records',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4C596A),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Page ${currentPage + 1} / $totalPages | $totalRecords records',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4C596A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPrev,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryEditDialog extends StatefulWidget {
  final ProductionEntryModel entry;

  const _EntryEditDialog({required this.entry});

  @override
  State<_EntryEditDialog> createState() => _EntryEditDialogState();
}

class _EntryEditDialogState extends State<_EntryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shiftCtrl;
  late final TextEditingController _machineCtrl;
  late final TextEditingController _itemCtrl;
  late final TextEditingController _customerCtrl;
  late final TextEditingController _ccd1Ctrl;
  late final TextEditingController _actualCtrl;
  late final TextEditingController _rejectionCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _endTimeCtrl;
  late final TextEditingController _notesCtrl;
  late String _approvalStatus;
  String? _dialogError;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _shiftCtrl = TextEditingController(text: entry.shift);
    _machineCtrl = TextEditingController(text: entry.machineId);
    _itemCtrl = TextEditingController(text: entry.itemId);
    _customerCtrl = TextEditingController(text: entry.customerId ?? '');
    _ccd1Ctrl = TextEditingController(text: entry.ccd1Quantity.toString());
    _actualCtrl = TextEditingController(text: entry.actualQuantity.toString());
    _rejectionCtrl = TextEditingController(text: entry.rejectionQuantity.toString());
    _startTimeCtrl = TextEditingController(text: entry.startTime);
    _endTimeCtrl = TextEditingController(text: entry.endTime);
    _notesCtrl = TextEditingController(text: entry.notes ?? '');
    _approvalStatus = (entry.approvalStatus ?? 'PENDING').trim().toUpperCase();
  }

  @override
  void dispose() {
    _shiftCtrl.dispose();
    _machineCtrl.dispose();
    _itemCtrl.dispose();
    _customerCtrl.dispose();
    _ccd1Ctrl.dispose();
    _actualCtrl.dispose();
    _rejectionCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int? _parseIntOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  int? _parseTimeInMinutes(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(text);
    if (match == null) return null;
    return (int.parse(match.group(1)!) * 60) + int.parse(match.group(2)!);
  }

  String? _validateNumberField(String? value, String label) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (int.tryParse(text) == null) return '$label must be a valid number.';
    if (int.parse(text) < 0) return '$label cannot be negative.';
    return null;
  }

  String? _validateTimeField(String? value, String label) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (_parseTimeInMinutes(text) == null) {
      return '$label must be in HH:mm format.';
    }
    return null;
  }

  Map<String, dynamic> _buildPayload() {
    final entry = widget.entry;
    final payload = <String, dynamic>{};

    void putIfChanged(String key, dynamic oldValue, dynamic newValue) {
      if (oldValue != newValue) payload[key] = newValue;
    }

    final shift = _shiftCtrl.text.trim();
    final machineId = _machineCtrl.text.trim();
    final itemId = _itemCtrl.text.trim();
    final customerId = _customerCtrl.text.trim();
    final ccd1 = _parseIntOrNull(_ccd1Ctrl.text.trim());
    final actual = _parseIntOrNull(_actualCtrl.text.trim());
    final rejection = _parseIntOrNull(_rejectionCtrl.text.trim());
    final startTime = _startTimeCtrl.text.trim();
    final endTime = _endTimeCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final status = _approvalStatus.trim().toUpperCase();

    putIfChanged('shift', entry.shift.trim(), shift);
    putIfChanged('machineId', entry.machineId.trim(), machineId);
    putIfChanged('itemId', entry.itemId.trim(), itemId);
    putIfChanged('customerId', (entry.customerId ?? '').trim(), customerId);
    if (ccd1 != null) putIfChanged('ccd1Quantity', entry.ccd1Quantity, ccd1);
    if (actual != null) putIfChanged('actualQuantity', entry.actualQuantity, actual);
    if (rejection != null) putIfChanged('rejectionQuantity', entry.rejectionQuantity, rejection);
    if (startTime.isNotEmpty) putIfChanged('startTime', entry.startTime.trim(), startTime);
    if (endTime.isNotEmpty) putIfChanged('endTime', entry.endTime.trim(), endTime);
    putIfChanged('notes', (entry.notes ?? '').trim(), notes);
    putIfChanged('approvalStatus', (entry.approvalStatus ?? 'PENDING').trim().toUpperCase(), status);
    return payload;
  }

  void _submit() {
    setState(() => _dialogError = null);
    if (!_formKey.currentState!.validate()) return;

    final actual = _parseIntOrNull(_actualCtrl.text.trim());
    final rejection = _parseIntOrNull(_rejectionCtrl.text.trim());
    if (actual != null && rejection != null && rejection > actual) {
      setState(() => _dialogError = 'Rejection Quantity cannot exceed Actual Quantity.');
      return;
    }
    final start = _parseTimeInMinutes(_startTimeCtrl.text.trim());
    final end = _parseTimeInMinutes(_endTimeCtrl.text.trim());
    if (start != null && end != null && end <= start) {
      setState(() => _dialogError = 'End time must be greater than Start time.');
      return;
    }

    final payload = _buildPayload();
    if (payload.isEmpty) {
      setState(() => _dialogError = 'No changes detected.');
      return;
    }
    Navigator.of(context).pop(payload);
  }

  Widget _adaptivePair({
    required Widget first,
    required Widget second,
    double spacing = 10,
  }) {
    final isCompact = MediaQuery.of(context).size.width < 520;
    if (isCompact) {
      return Column(
        children: [
          first,
          SizedBox(height: spacing),
          second,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: first),
        SizedBox(width: spacing),
        Expanded(child: second),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Edit & Review Entry'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dialogError != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFB4AA)),
                    ),
                    child: Text(
                      _dialogError!,
                      style: const TextStyle(
                        color: Color(0xFF8F1D18),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                _adaptivePair(
                  first: TextFormField(
                    controller: _shiftCtrl,
                    decoration: const InputDecoration(labelText: 'Shift'),
                  ),
                  second: DropdownButtonFormField<String>(
                    value: _approvalStatus,
                    decoration: const InputDecoration(labelText: 'Approval Status'),
                    items: const [
                      DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _approvalStatus = value);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _machineCtrl,
                  decoration: const InputDecoration(labelText: 'Machine ID'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _itemCtrl,
                  decoration: const InputDecoration(labelText: 'Item ID'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _customerCtrl,
                  decoration: const InputDecoration(labelText: 'Customer ID'),
                ),
                const SizedBox(height: 10),
                _adaptivePair(
                  first: TextFormField(
                    controller: _ccd1Ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'CCD1 Quantity'),
                    validator: (value) => _validateNumberField(value, 'CCD1 Quantity'),
                  ),
                  second: TextFormField(
                    controller: _actualCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Actual Quantity'),
                    validator: (value) => _validateNumberField(value, 'Actual Quantity'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _rejectionCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rejection Quantity'),
                  validator: (value) => _validateNumberField(value, 'Rejection Quantity'),
                ),
                const SizedBox(height: 10),
                _adaptivePair(
                  first: TextFormField(
                    controller: _startTimeCtrl,
                    decoration: const InputDecoration(labelText: 'Start Time', hintText: 'HH:mm'),
                    validator: (value) => _validateTimeField(value, 'Start time'),
                  ),
                  second: TextFormField(
                    controller: _endTimeCtrl,
                    decoration: const InputDecoration(labelText: 'End Time', hintText: 'HH:mm'),
                    validator: (value) => _validateTimeField(value, 'End time'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Apply Changes')),
      ],
    );
  }
}
