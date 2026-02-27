import 'package:jerelo/jerelo.dart';

extension ContAbsurdifyExtension<E, F, A> on Cont<E, F, A> {
  /// Widens the then (success) channel from [Never] to [A] if this continuation
  /// has a [Never] success type; otherwise returns `this` unchanged.
  ///
  /// This is a type-safe no-op that allows a `Cont<E, F, Never>` to be used
  /// where a `Cont<E, F, A>` is expected.
  Cont<E, F, A> thenAbsurdify() {
    Cont<E, F, A> cont = this;

    if (cont is Cont<E, F, Never>) {
      cont = cont.thenAbsurd<A>();
    }

    return cont;
  }

  /// Widens the else (error) channel from [Never] to [F] if this continuation
  /// has a [Never] error type; otherwise returns `this` unchanged.
  ///
  /// This is a type-safe no-op that allows a `Cont<E, Never, A>` to be used
  /// where a `Cont<E, F, A>` is expected.
  Cont<E, F, A> elseAbsurdify() {
    Cont<E, F, A> cont = this;

    if (cont is Cont<E, Never, A>) {
      cont = cont.elseAbsurd<F>();
    }

    return cont;
  }

  /// Widens both the then and else channels from [Never] to [A] and [F]
  /// respectively, if needed; otherwise returns `this` unchanged.
  ///
  /// Combines [thenAbsurdify] and [elseAbsurdify] in a single call.
  Cont<E, F, A> absurdify() {
    Cont<E, F, A> cont = this;

    if (cont is Cont<E, Never, Never>) {
      return Cont.fromRun((runtime, observer) {
        cont.runWith(
          runtime,
          observer.copyUpdate<Never, Never>(
            onCrash: observer.onCrash,
            onElse: (Never n) {},
            onThen: (Never n) {},
          ),
        );
      });
    }

    return thenAbsurdify().elseAbsurdify();
  }
}

extension ContElseNeverExtension<E, A>
    on Cont<E, Never, A> {
  /// Converts a continuation that never produces a business-logic error to
  /// any desired error type [F].
  ///
  /// The absurd method implements the "ex falso quodlibet" principle from type
  /// theory. Since [Never] is an uninhabited type, the mapping function can
  /// never actually execute, but the type system accepts the transformation.
  ///
  /// This is useful for unifying error types when composing continuations that
  /// cannot fail on the else channel with ones that can.
  Cont<E, F, A> elseAbsurd<F>() {
    return elseMap((
      Never never,
    ) {
      return never;
    });
  }
}

/// Extension for running continuations that never produce a value.
///
/// This extension provides specialized methods for [Cont]<[E], [Never]> where only
/// termination is expected, simplifying the API by removing the unused value callback.
extension ContThenNeverExtension<E, F>
    on Cont<E, F, Never> {
  /// Converts a continuation that never produces a value to any desired type.
  ///
  /// The absurd method implements the principle of "ex falso quodlibet" (from
  /// falsehood, anything follows) from type theory. It allows converting a
  /// `Cont<E, Never>` to `Cont<E, A>` for any type `A`.
  ///
  /// Since `Never` is an uninhabited type with no possible values, the mapping
  /// function `(Never never) => never` can never actually execute. However, the
  /// type system accepts this transformation as valid, enabling type-safe
  /// conversion from a continuation that cannot produce a value to one with
  /// any desired value type.
  ///
  /// This is particularly useful when:
  /// - Working with continuations that run forever (e.g., from [thenForever])
  /// - Matching types with other continuations in composition
  /// - Converting terminating-only continuations to typed continuations
  ///
  /// Type parameters:
  /// - [A]: The desired value type for the resulting continuation
  ///
  /// Returns a continuation with the same environment type but a different
  /// value type parameter.
  ///
  /// Example:
  /// ```dart
  /// // A server that runs forever has type Cont<Env, Never>
  /// final server = handleRequests().thenForever();
  ///
  /// // Convert to Cont<Env, String> to match other continuation types
  /// final serverAsString = server.absurd<String>();
  /// ```
  Cont<E, F, A> thenAbsurd<A>() {
    return thenMap<A>(
      (
        Never // gonna give you up
            never, // gonna let you down
      ) {
        return never; // gonna run around and desert you
      },
    );
  }
}

/*
  ..:..............:::------:::::::::----:-:::.::-----:::--::----::::::::----------:::::::::..........
................::::-------::::::::---::::::--=-=+*++*##**++=--:::::::----------:::::::::....:......
..............::::::::--:--:::::::::---::.:-*##########*******=::::::::----------::::..:...........:
..........::::::..::::::::-----------------=+*###############**+--------------------:..:............
.......:::::::....::::::...:----:::..:-:-=+***######%%#######***+------:::--------------:...........
..:::::::::::.....::::::.::--::::::::-===++**##################*+-------::------::-------:..........
:::::::::::::.....::::::::::::.......::-=++*++++=====+=----==*##*=:.------------::------------:.....
:::.....:::::.....::::::::............:=*#*+=++====----------=+**=:::-----------:::.:----------::...
:::........:::....:::::::::.:........:-*#*++++++====--=-------=**=::::::--------::::-----::::----::.
:..........::::...::::::::...........:-***+++++++===--==-----==**=::::::--------::::---:::::::----::
:........:::::::::::::::::...........:-+*++++*+++**+=-=+++=====*+-:::::---------::----::::::::::---:
::::.....:::...::::::::::.........::..:+++++++**+++++=-=+*+====+:......:-----------:----:::::::::--:
::::::..::.......:::::::::..........:====-=++====++++=--=======-....:::::---------:::----::::-----::
:....::::........::::::::::::.......-=++=-=+++==+++++=--------==::..:.::---------::::::----------:::
:......::...... ..::::::::--::.......-+====++++++++**++=-----==-:::.:-----------::::..::---------:::
:.......::.......:::::::..:---:.....:-==+++++++++++==-=-----===:::::-----:-------:.:.:.:--:..:::----
:........:........::::::..::------------:-=++++++++===--------:::------::::------:.:...:-:.....:----
:........:.......::::::::-------------.::-=++++++++===--==--------------::-------:.....:-:.......:--
:::......::......:::::::::-::...:.:---:---==+++++=====--===----:::.:-------------:.....-:......::---
::::......:......:::::::::::.:....::--:::-++++++++===-====-:---::::::::----------:::..:-:.....::::--
:::::.....::.....::::::::...:...::-------=+++++++++++=====-----::..::.::---------:::.:--:.....::::::
..::::...:::::::.:::::::....:::----------=+++++++++=======-::-----::::::::-------:::----:....::::...
.:::::::::....::::::::::...:.::----::::--=+++++++=========-==::----::::::::--------------:.:--::....
------::::......::::::---::::---------:-=+++++++++========:+##=:----::::::----------:::---:---::....
--------::.:....::::-------:--==+++=-=::---=+++++========--*####*=---::::---------::::::----------:.
::------:.......:---------=++*#####+=++++*++++++++===++=:-+###%%%%%#*+-::---------:::::::-----------
.---------:::..:-----==+*##%%%%%%%#*=++++++====++++++=-::=##%%%%%%%%%%%##*=::-----::::::-------:....
.--::-----:....:=++**##%%%%%%%%%%%%#=+*++++=+==++++--::::=#%%%%%%%%%%%%%%%%%##=::::::::---------::::
:--:..:----:..:=##%%%%%%%%%%%%%%%%%#=+***++-=+++=--:::::-*%%%%%%%%%#*+#%%%%%%%%%#*-::::-----:---::::
:-::.::-----::-*%%%%%%#%%%%%%%%%%%%#=+***++===---::::::=#%%%%%%%%#*+++===+#%%%%%%%%#*:-----:::---:::
:::....:----::+#%%%%%%%%%%%%%%%%%%%%******++*+++++=-::=%%%%%%%%%%*+++++++===*%%%%%%%#*------::---:::
:::.:..:------*#%%%%%%%%%%%%%%%%%%%%****++=***++===++*%%%%%%%%%%#+++++======+#%%%%%%##+---:::::---::
::...::--::--=#%%%%%%%%%%%%%%%%%%%%%%%*==+**+=--=++*##%%%%%%%%%%#++++=======+%%%%%%%%#+:--::::::--::
-:..:----:::-=#%%%%%%%%%%%%%%%%%%%%%%%#======++**#***#%%%%%%%%%%%#**+======+*%%%%%%%%%*-----::::---:
-:::-------:+*#%%%%%%%%%%%%%%%%%%%%%%%+-==+*###**+==+%%%%%%%%%%%%%%*++=====+#%%%%%%%%#*------:::---:
::----:::--=*#%%%%%%%%%%%%%%%%%%%%%%%%+-==***+=--=+*%%%%%%%%%%%%%%%*++=====+#%%%%%%%%#*-------::---:
----:.....:+#%%%%%%%%%%%%%%%%%%%%%%%%%+--==--=+*#%%%%%%%%%%%%%%%%@%#*++====+#%%%%%%%%%*::::---------
---::::.:::+%%%%%%%%%%%%%%%%%%%%%%%%%%*==+##%%%%#+=+%%%%%%%%%%%%%@@%**+====+#%%%%%%%%%*:::::::------
-:.......:-+%%%%%%%%%%%%%%%%%%%%%%%%%%%**##*+=====+#%%%%%%%%%%%%@@@@%**++===+%%%%%%%%%#-::::::------
:........:-*%%%%%%%%%%%@%%%%%%%%%%%%%%%**+===+*#%%%%%%%%%%%%%%%@@@@@@@%%%%%%#%%%%%%%%%#=:::::::::---
:........:=*%%%%%%%%%%%@%%%%%%%%%%%%%%%**####%%#***%%%%%%%%%%@@@@@@@@@@@%####%%%%%%%%%#=::::--:-----
-::...:::=+#%%%%%@@@@@@@@@@%%%%@%%%%%%%**##*+++++*#%%%%%%%%@@@@@@@@@@@@@%%%%%%%%##%%%%%*-::::::::---
---:::::=++#%%%%%@@@@@@@@@@@%%@@%%%%%%%***+++**##%%@%@%%%@@@@@@@@@@@@@@@@@@@@%%%%#%%%%%%#=-:::------
----::-*###%%%%%@@@@@@@@@@@@%#+++++++++**#########%%%%%%%@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%*-::-------
:----+%%%%%@@@@@@@@@@%@@@@@#**+++++*+++**####**++*%@%%@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%*=------=-
::--=##%%%##%%%%%%%%*##**#*++++++++++++*********#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%%%%*----==
:::-*%%%%%%#*###%%%#**##%%#****++++++++*****###%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%%%%%%%%*=-==
--:-*%%%###%%%%%@%#*%%%%%%#****++*++++***%%%%%%#*#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%@%%%@%%%%%*==
:::--*%#%%%%%%%@%%#%%%%%%%#****++*++++%****+++**#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%%%%@%%%%%#==
::-===#%%%%%%%%%%%%%@@@%%%##*******#%@@#****###%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%@@%%%%+==
:--===#%%%%%%%%%%%%%%%%@@@@@%%%@@@@@@@@##%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%@%%%+===
-=----*%%%%%%%%%%%###%%%%%%%@@@@@@@@@@@#********#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%%*-===
----:--=*#%%%%%%%%%#%%@@@@@@@@@@@@@@@@%#*####%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%#=====
::::....:::--=========-================--==------=============================================::::::

   */
