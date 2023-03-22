import 'dart:async';

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/main.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/categoryIcon.dart';
import 'package:budget/widgets/fab.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/globalSnackBar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/pageFramework.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:budget/widgets/editRowEntry.dart';

class EditCategoriesPage extends StatefulWidget {
  EditCategoriesPage({
    Key? key,
    required this.title,
  }) : super(key: key);
  final String title;

  @override
  _EditCategoriesPageState createState() => _EditCategoriesPageState();
}

class _EditCategoriesPageState extends State<EditCategoriesPage> {
  bool dragDownToDismissEnabled = true;
  int currentReorder = -1;
  String searchValue = "";

  @override
  void initState() {
    Future.delayed(Duration.zero, () {
      database.fixOrderCategories();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (searchValue != "") {
          setState(() {
            searchValue = "";
          });
          return false;
        } else {
          return true;
        }
      },
      child: PageFramework(
        horizontalPadding: getHorizontalPaddingConstrained(context),
        dragDownToDismiss: true,
        dragDownToDismissEnabled: dragDownToDismissEnabled,
        title: widget.title,
        navbar: false,
        floatingActionButton: AnimateFABDelayed(
          fab: Padding(
            padding: EdgeInsets.only(bottom: bottomPaddingSafeArea),
            child: FAB(
              tooltip: "Add Category",
              openPage: AddCategoryPage(
                title: "Add Category",
              ),
            ),
          ),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextInput(
                labelText: "Search categories...",
                icon: Icons.search_rounded,
                onSubmitted: (value) {
                  setState(() {
                    searchValue = value;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    searchValue = value;
                  });
                },
                autoFocus: false,
              ),
            ),
          ),
          StreamBuilder<List<TransactionCategory>>(
            stream: database.watchAllCategories(
                searchFor: searchValue == "" ? null : searchValue),
            builder: (context, snapshot) {
              if (snapshot.hasData && (snapshot.data ?? []).length <= 0) {
                return SliverToBoxAdapter(
                  child: NoResults(
                    message: "No categories found.",
                  ),
                );
              }
              if (snapshot.hasData && (snapshot.data ?? []).length > 0) {
                return SliverReorderableList(
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
                    TransactionCategory category = snapshot.data![index];
                    Color backgroundColor = dynamicPastel(
                        context,
                        HexColor(category.colour,
                            defaultColor:
                                Theme.of(context).colorScheme.primary),
                        amountLight: 0.55,
                        amountDark: 0.35);
                    return EditRowEntry(
                      canReorder: searchValue == "" &&
                          (snapshot.data ?? []).length != 1,
                      currentReorder:
                          currentReorder != -1 && currentReorder != index,
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      key: ValueKey(index),
                      backgroundColor: backgroundColor,
                      content: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CategoryIcon(
                            categoryPk: category.categoryPk,
                            size: 40,
                            category: category,
                            canEditByLongPress: false,
                          ),
                          Container(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFont(
                                  text: category.name +
                                      " - " +
                                      category.order.toString(),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                                StreamBuilder<List<int?>>(
                                  stream: database
                                      .watchTotalCountOfTransactionsInWalletInCategory(
                                          appStateSettings["selectedWallet"],
                                          category.categoryPk),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data != null) {
                                      return TextFont(
                                        textAlign: TextAlign.left,
                                        text: snapshot.data![0].toString() +
                                            pluralString(snapshot.data![0] == 1,
                                                " transaction"),
                                        fontSize: 14,
                                        textColor: Theme.of(context)
                                            .colorScheme
                                            .black
                                            .withOpacity(0.65),
                                      );
                                    } else {
                                      return TextFont(
                                        textAlign: TextAlign.left,
                                        text: "/ transactions",
                                        fontSize: 14,
                                        textColor: Theme.of(context)
                                            .colorScheme
                                            .black
                                            .withOpacity(0.65),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      index: index,
                      onDelete: () {
                        deleteCategoryPopup(context, category);
                      },
                      openPage: AddCategoryPage(
                        title: "Edit Category",
                        category: category,
                      ),
                    );
                  },
                  itemCount: snapshot.data!.length,
                  onReorder: (_intPrevious, _intNew) async {
                    TransactionCategory oldCategory =
                        snapshot.data![_intPrevious];

                    if (_intNew > _intPrevious) {
                      await database.moveCategory(oldCategory.categoryPk,
                          _intNew - 1, oldCategory.order);
                    } else {
                      await database.moveCategory(
                          oldCategory.categoryPk, _intNew, oldCategory.order);
                    }
                  },
                );
              }
              return SliverToBoxAdapter(
                child: Container(),
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 85),
          ),
        ],
      ),
    );
  }
}

class RefreshButton extends StatefulWidget {
  final Function onTap;

  RefreshButton({required this.onTap});

  @override
  _RefreshButtonState createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Tween<double> _tween;
  bool _isEnabled = true;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubicEmphasized,
    );
    _tween = Tween<double>(begin: 0.0, end: 12.5664 / 2);
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _animationController.forward(from: 0.0);
  }

  void _onTap() async {
    if (_isEnabled) {
      _startAnimation();
      setState(() {
        _isEnabled = false;
      });
      await widget.onTap();
      Timer(Duration(seconds: 5), () {
        if (mounted)
          setState(() {
            _isEnabled = true;
          });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _tween.evaluate(_animation),
          child: AnimatedOpacity(
            opacity: _isEnabled ? 1 : 0.3,
            duration: Duration(milliseconds: 500),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded),
              color: Theme.of(context).colorScheme.secondary,
              onPressed: () => _onTap(),
            ),
          ),
        );
      },
    );
  }
}

void deleteCategoryPopup(context, TransactionCategory category,
    {Function? afterDelete}) {
  openPopup(
    context,
    title: "Delete " + category.name + " category?",
    description:
        "This will delete all transactions associated with this category.",
    icon: Icons.delete_rounded,
    onCancel: () {
      Navigator.pop(context);
    },
    onCancelLabel: "Cancel",
    onSubmit: () async {
      loadingIndeterminateKey.currentState!.setVisibility(true);
      await database.deleteCategory(category.categoryPk, category.order);
      await database.deleteCategoryTransactions(category.categoryPk);
      loadingIndeterminateKey.currentState!.setVisibility(false);
      Navigator.pop(context);
      openSnackbar(
        SnackbarMessage(title: "Deleted " + category.name, icon: Icons.delete),
      );
      if (afterDelete != null) afterDelete();
    },
    onSubmitLabel: "Delete",
  );
}
