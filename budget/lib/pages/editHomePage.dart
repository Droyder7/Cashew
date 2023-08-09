import 'package:budget/database/tables.dart';
import 'package:budget/pages/homePage/homePageLineGraph.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/modified/reorderable_list.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/editRowEntry.dart';
import 'package:budget/widgets/moreIcons.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/radioItems.dart';
import 'package:budget/widgets/selectItems.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/pages/addBudgetPage.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/showDatePicker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' hide SliverReorderableList;
import 'package:flutter/material.dart' hide SliverReorderableList;
import 'package:flutter/services.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/functions.dart';

// We need to refresh the home page when this route is popped

class EditHomePageItem {
  final IconData icon;
  final String name;
  bool isEnabled;
  final Function(bool value) onSwitched;
  final Function()? onTap;
  List<Widget>? extraWidgetsBelow;

  EditHomePageItem({
    required this.icon,
    required this.name,
    required this.isEnabled,
    required this.onSwitched,
    this.onTap,
    this.extraWidgetsBelow,
  });
}

class EditHomePage extends StatefulWidget {
  const EditHomePage({super.key});

  @override
  State<EditHomePage> createState() => _EditHomePageState();
}

class _EditHomePageState extends State<EditHomePage> {
  bool dragDownToDismissEnabled = true;
  int currentReorder = -1;

  Map<String, EditHomePageItem> editHomePageItems = {};
  List<dynamic> keyOrder = [];

  @override
  void initState() {
    Future.delayed(Duration.zero, () async {
      setState(() {
        editHomePageItems = {
          "wallets": EditHomePageItem(
            icon: Icons.account_balance_wallet_rounded,
            name: "wallets".tr(),
            isEnabled: appStateSettings["showWalletSwitcher"],
            onSwitched: (value) {
              updateSettings("showWalletSwitcher", value,
                  pagesNeedingRefresh: [], updateGlobalState: false);
            },
          ),
          "budgets": EditHomePageItem(
            icon: MoreIcons.chart_pie,
            name: "budgets".tr(),
            isEnabled: appStateSettings["showPinnedBudgets"],
            onSwitched: (value) {
              updateSettings("showPinnedBudgets", value,
                  pagesNeedingRefresh: [], updateGlobalState: false);
            },
            onTap: () async {
              String defaultLabel = "default-line-graph".tr();
              List<Budget> allBudgets = await database.getAllBudgets();
              List<Budget> allPinnedBudgets =
                  await database.getAllPinnedBudgets().$2;
              openBottomSheet(
                context,
                PopupFramework(
                  title: "select-budgets".tr(),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: SettingsContainerSwitch(
                          title: "total-spent".tr(),
                          descriptionWithValue: (value) => value
                              ? "total-spent-description-1".tr()
                              : "total-spent-description-2".tr(),
                          onSwitched: (value) {
                            updateSettings("showTotalSpentForBudget", value,
                                pagesNeedingRefresh: [0, 2],
                                updateGlobalState: false);
                          },
                          initialValue:
                              appStateSettings["showTotalSpentForBudget"],
                          icon: Icons.center_focus_weak_rounded,
                        ),
                      ),
                      SelectItems(
                        checkboxCustomIconSelected: Icons.push_pin_rounded,
                        checkboxCustomIconUnselected: Icons.push_pin_outlined,
                        items: [
                          for (Budget budget in allBudgets)
                            budget.budgetPk.toString()
                        ],
                        displayFilter: (budgetPk) {
                          for (Budget budget in allBudgets)
                            if (budget.budgetPk.toString() ==
                                budgetPk.toString()) {
                              return budget.name;
                            }
                          return defaultLabel;
                        },
                        initialItems: [
                          for (Budget budget in allPinnedBudgets)
                            budget.budgetPk.toString()
                        ],
                        onChangedSingleItem: (value) async {
                          Budget budget = allBudgets[allBudgets.indexWhere(
                              (item) => item.budgetPk == int.parse(value))];
                          Budget budgetToUpdate =
                              await database.getBudgetInstance(budget.budgetPk);
                          await database.createOrUpdateBudget(
                            budgetToUpdate.copyWith(
                                pinned: !budgetToUpdate.pinned),
                            updateSharedEntry: false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          "overdueUpcoming": EditHomePageItem(
            icon: getTransactionTypeIcon(TransactionSpecialType.subscription),
            name: "overdue-and-upcoming".tr(),
            isEnabled: appStateSettings["showOverdueUpcoming"],
            onSwitched: (value) {
              updateSettings("showOverdueUpcoming", value,
                  pagesNeedingRefresh: [], updateGlobalState: false);
            },
          ),
          "creditDebts": EditHomePageItem(
            icon: getTransactionTypeIcon(TransactionSpecialType.credit),
            name: "lent-and-borrowed".tr(),
            isEnabled: appStateSettings["showCreditDebt"],
            onSwitched: (value) {
              updateSettings("showCreditDebt", value,
                  pagesNeedingRefresh: [], updateGlobalState: false);
            },
          ),
          "allSpendingSummary": EditHomePageItem(
            icon: Icons.expand_rounded,
            name: "income-and-expenses".tr(),
            isEnabled: appStateSettings["showAllSpendingSummary"],
            onSwitched: (value) {
              updateSettings("showAllSpendingSummary", value,
                  pagesNeedingRefresh: [], updateGlobalState: false);
            },
            onTap: () async {
              openBottomSheet(
                context,
                PopupFramework(
                  title: "select-start-date".tr(),
                  child: SelectStartDate(
                    initialDateTime:
                        appStateSettings["incomeExpenseStartDate"] == null
                            ? null
                            : DateTime.parse(
                                appStateSettings["incomeExpenseStartDate"]),
                    onSelected: (DateTime? dateTime) {
                      updateSettings("incomeExpenseStartDate",
                          dateTime == null ? null : dateTime.toString(),
                          pagesNeedingRefresh: [], updateGlobalState: false);
                    },
                  ),
                ),
              );
            },
          ),
          "spendingGraph": EditHomePageItem(
            icon: Icons.insights_rounded,
            name: "spending-graph".tr(),
            isEnabled: appStateSettings["showSpendingGraph"],
            onSwitched: (value) {
              updateSettings("showSpendingGraph", value,
                  pagesNeedingRefresh: [], updateGlobalState: false);
            },
            extraWidgetsBelow: [],
            onTap: () async {
              String defaultLabel = "default-line-graph".tr();
              String customLabel = "custom-line-graph".tr();
              List<Budget> allBudgets = await database.getAllBudgets();
              openBottomSheet(
                context,
                PopupFramework(
                  title: "select-graph".tr(),
                  child: RadioItems(
                    items: [
                      defaultLabel,
                      customLabel,
                      ...[
                        for (Budget budget in allBudgets)
                          budget.budgetPk.toString()
                      ],
                    ],
                    displayFilter: (budgetPk) {
                      for (Budget budget in allBudgets)
                        if (budget.budgetPk.toString() == budgetPk.toString()) {
                          return budget.name;
                        }
                      if (budgetPk == customLabel)
                        return ('${customLabel} (${getWordedDateShortMore(DateTime.parse(appStateSettings["lineGraphStartDate"]), includeYear: true)})');
                      return budgetPk;
                    },
                    initial: appStateSettings["lineGraphDisplayType"] ==
                            LineGraphDisplay.Default30Days.index
                        ? defaultLabel
                        : appStateSettings["lineGraphDisplayType"] ==
                                LineGraphDisplay.CustomStartDate.index
                            ? customLabel
                            : appStateSettings["lineGraphReferenceBudgetPk"]
                                .toString(),
                    onChanged: (value) async {
                      if (value == defaultLabel) {
                        updateSettings(
                          "lineGraphDisplayType",
                          LineGraphDisplay.Default30Days.index,
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                      } else if (value == customLabel) {
                        DateTime? picked = await showCustomDatePicker(
                          context,
                          DateTime.parse(
                              appStateSettings["lineGraphStartDate"]),
                        );
                        if (picked == null || picked.isAfter(DateTime.now())) {
                          if (DateTime.parse(
                                  appStateSettings["lineGraphStartDate"])
                              .isAfter(DateTime.now())) {
                            picked = DateTime.now();
                          } else {
                            picked = DateTime.parse(
                                appStateSettings["lineGraphStartDate"]);
                          }
                        }
                        updateSettings(
                          "lineGraphStartDate",
                          (picked ?? appStateSettings["lineGraphDisplayType"])
                              .toString(),
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                        updateSettings(
                          "lineGraphDisplayType",
                          LineGraphDisplay.CustomStartDate.index,
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                      } else {
                        updateSettings(
                          "lineGraphReferenceBudgetPk",
                          int.parse(value),
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                        updateSettings(
                          "lineGraphDisplayType",
                          LineGraphDisplay.Budget.index,
                          pagesNeedingRefresh: [],
                          updateGlobalState: false,
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
            },
          ),
        };
        keyOrder = List<String>.from(appStateSettings["homePageOrder"]
            .map((element) => element.toString()));
      });
      super.initState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      horizontalPadding: getHorizontalPaddingConstrained(context),
      dragDownToDismiss: true,
      dragDownToDismissEnabled: dragDownToDismissEnabled,
      title: "edit-home".tr(),
      slivers: [
        SliverReorderableList(
          onReorderStart: (index) {
            HapticFeedback.heavyImpact();
            setState(() {
              dragDownToDismissEnabled = false;
              currentReorder = index;
            });
          },
          onReorderEnd: (_) {
            setState(() {
              dragDownToDismissEnabled = true;
              currentReorder = -1;
            });
          },
          itemBuilder: (context, index) {
            String key = keyOrder[index];
            return EditRowEntry(
              canReorder: true,
              currentReorder: currentReorder != -1 && currentReorder != index,
              padding: EdgeInsets.only(left: 18, right: 0, top: 16, bottom: 16),
              key: ValueKey(key),
              extraWidget: Row(
                children: [
                  getPlatform() == PlatformOS.isIOS
                      ? CupertinoSwitch(
                          activeColor: Theme.of(context).colorScheme.primary,
                          value: editHomePageItems[key]!.isEnabled,
                          onChanged: (value) {
                            editHomePageItems[key]!.onSwitched(value);
                            setState(() {
                              editHomePageItems[key]!.isEnabled = value;
                            });
                          },
                        )
                      : Switch(
                          activeColor: Theme.of(context).colorScheme.primary,
                          value: editHomePageItems[key]!.isEnabled,
                          onChanged: (value) {
                            editHomePageItems[key]!.onSwitched(value);
                            setState(() {
                              editHomePageItems[key]!.isEnabled = value;
                            });
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                ],
              ),
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    editHomePageItems[key]!.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: TextFont(
                      text: editHomePageItems[key]!.name,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      maxLines: 5,
                    ),
                  ),
                  editHomePageItems[key]?.onTap == null
                      ? SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                ],
              ),
              extraWidgetsBelow: editHomePageItems[key]?.extraWidgetsBelow ??
                  [SizedBox.shrink()],
              canDelete: false,
              index: index,
              onDelete: () {},
              onTap: editHomePageItems[key]?.onTap ?? () {},
              openPage: Container(),
            );
          },
          itemCount: editHomePageItems.keys.length,
          onReorder: (oldIndex, newIndex) async {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final String item = keyOrder.removeAt(oldIndex);
              keyOrder.insert(newIndex, item);
            });
            updateSettings("homePageOrder", keyOrder,
                pagesNeedingRefresh: [], updateGlobalState: false);
            return true;
          },
        ),
      ],
    );
  }
}

class SelectStartDate extends StatefulWidget {
  const SelectStartDate(
      {required this.initialDateTime, required this.onSelected, super.key});
  final DateTime? initialDateTime;
  final Function(DateTime?) onSelected;

  @override
  State<SelectStartDate> createState() => _SelectStartDateState();
}

class _SelectStartDateState extends State<SelectStartDate> {
  late DateTime? selectedDate = widget.initialDateTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              selectedDate = null;
              widget.onSelected(null);
            });
          },
          icon: Icon(Icons.undo_rounded),
        ),
        TappableTextEntry(
          title: selectedDate == null
              ? "all-time".tr()
              : getWordedDateShortMore(selectedDate!, includeYear: true),
          placeholder: "",
          onTap: () async {
            final DateTime? picked = await showCustomDatePicker(
                context, selectedDate ?? DateTime.now());
            setState(() {
              selectedDate = picked ?? selectedDate;
            });
            widget.onSelected(selectedDate);
          },
          fontSize: 25,
          fontWeight: FontWeight.bold,
          internalPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
        ),
      ],
    );
  }
}
