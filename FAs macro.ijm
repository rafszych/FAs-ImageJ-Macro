//makro do pomiaru kontaktow zogniskowanych
//wykorzystuje do tego dwa kanaly, jeden od kontaktow zogniskowanych (np winkulina), drugi do pomiaru powierzhni komorek (np F-aktyna)
//w przypadku braku drugiego kanalu mozna ponownie dac kanal od kontaktow zogniskowanych

/*	kolejnosc dzialania makra:
		1. wybranie przez uzytkownika nadfolderu zwierajacego foldery ze zdjeciami
		2. wyrownanie poziomu jasnosci zdjecia z TIRFa (gaussian blur, itd.)
		3. wybranie przez uzytkowanika thresholdu dla kontaktow
		4. pomiar kontaktow i zapisanie wynikow w odpowiednim folderze
		5. wybor przez uzytkownika thresholdu dla pomiaru powierzchni komorek oraz sam pomiar powierzchni
 */

//utworzenie okna, w ktorym nalezy podac suffix dla odpowiednich kanalow
//na podstawie podanych suffixow program bedzie przeszukiwal podfoldery i otwieral odpowiednie zdjecia

Dialog.create("Pomiar FAs");
//suffixy zdjec po eksportowaniu z LASX maja najczesciej na koncu ch0X gdzie 'X' to cyfra odpowiadajaca odpowiedniemu kanalowi
Dialog.addString("Suffix kanalu z kontaktami zogniskowanymi: ", "ch00");
Dialog.addString("Suffix kanalu z F-aktyny: ", "ch02");
Dialog.show();

FAs_suffix = Dialog.getString() + ".";
Factin_suffix = Dialog.getString() + ".";

//przy eksportowaniu z LASX z opcja by eksportowac do oddzielnych folderow powstaje jeden folder nadrzedny,
//w ktorym znajduja sie foldery zawierajace zdjecia oddzielnych kanalow
//nalezy wybrac ten NADRZEDNY folder
dir1 = getDirectory("Wybierz folder zawierajacy podfoldery ze zdjeciami komorek");

//lista zawierajaca wszystkie pliki w nadrzednym folderze
list = getFileList(dir1);
n = list.length;

setBatchMode(true);

//glowna petla idaca po wszystkich plikach w folderze nadrzednym
for(i = 0; i < n; i++){
	//print("Przetwarzanie " + (i + 1) + " z " + n + "    " + list[i]);
	
	//przechowuje adres kolejnych folderow podrzednych
	current_dir = dir1 + list[i];

	if(!(File.isDirectory(current_dir))){
		continue;
	}
	
	//lista ze wszystkimi plikami w folderze podrzednym
	sub_dir_list = getFileList(current_dir);
	m = sub_dir_list.length;
	
	//zmienne do przechowywania nazw plikow zawierajacyh odpowiednie suffixy
	FAs = "";
	Factin = "";
	
	//petla idaca po plikach w folderze podrzednym
	for(j = 0; j < m; j++){
		
		//sprawdza, czy suffixy znajduja sie w nazwie pliku, jezeli tak to przechwytuje nazwe pliku
		if(indexOf(sub_dir_list[j], FAs_suffix) != -1) FAs = sub_dir_list[j];
		
		if(indexOf(sub_dir_list[j], Factin_suffix) != -1) Factin = sub_dir_list[j];
		
	}
	
	//otwieranie oryginalnego obrazu z kontaktami zogniskowanymi i przechwycenie nazwy
	FAs_image = current_dir + File.separator + FAs;
	open(FAs_image);
	FAs_open = "";
	FAs_open = getTitle();
	
	
	//obraz, na ktorym bedzie wykonywany gaussian blur
	selectWindow(FAs_open);
	run("Duplicate...", " ");
	FAs_open_duplicate = "";
	FAs_open_duplicate = getTitle();


	//Okno, w ktorym bedzie obraz oryginalny i maska z zaznaczonych FAs,
	//by ocenic, czy dobrze byl dobrany threshold
	selectWindow(FAs_open);
	run("Duplicate...", " ");
	rename("Probny threshold - animacja");
	FAs_animation = "";
	FAs_animation = getTitle();


	//okno musi miec format 8-bitowy by do stack'u mozna bylo dodac maske, ktora ma format 8-bitowy
	selectWindow(FAs_animation);
	setOption("ScaleConversions", true);
	run("8-bit");

	
	//wykonuje gaussian blur z zadanym parametrem sigma
	selectWindow(FAs_open_duplicate);
	run("Gaussian Blur...", "sigma=30");

	
	//odjecie od oryginalnego obrazu tego po gaussian blur wyrownuje poziom szarosci,
	//co jest szczegolnie wazne przy zdjeciach z TIRFa, ktore sa znaczaco ciemniejsze na brzegach
	selectWindow(FAs_open);
	imageCalculator("Subtract create", FAs_open, FAs_open_duplicate);
	//przechwycenie nazwy obrazu powstalego w wyniku powyzszego odejmowania
	after_gaussian_blur = "";
	after_gaussian_blur = getTitle();
	
	
	//zamykanie niepotrzebnego juz zdjecia
	selectWindow(FAs_open_duplicate);
	close();
	selectWindow(FAs_open);
	close();
	
	
	//CLAHE rowniez wyrownuje jasnosc w obrebie calego zdjecia i lokalnie zwieksza kontrast, co ulatwia rozpoznanie kontaktow
	selectWindow(after_gaussian_blur);
	run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate) ");
	//Tubeness pomaga z rozdzielaniem kontaktow ktore leza bezposrednio obok siebie
	//wartosc sigma tutaj to tyle jaki rozmiar ma piksel ze zdjec z TIRFa
	run("Tubeness", "sigma=0.184 use");
	//zmienia nazwe okna, ze juz jest po etapie tubeness
	rename("Summary of " + list[i]);
	after_tubeness = "";
	after_tubeness = getTitle();
	selectWindow(after_gaussian_blur);
	close();


	selectWindow(after_tubeness);
	//taka skala jest na nasym mikroskopie, najlepiej upewnic sie, ze taka jest skala,
	//zwlaszcza jezeli zdjecia byly zbierane z roznymi ustawieniami binowania
	run("Set Scale...", "distance=1 known=0.184 pixel=1.000 unit=um");


	//zmienne do przechowywania testowanego thresholdu, by je wykorzystac poza petla
	lower_threshold = 0.0;
	upper_threshold = 0.0;

	first_run = true;
	
	//operacje w tej petli beda wykonywane az uzytkownik nie zaznaczy, ze threshold zostal poprawnie dobrany
	do {
		selectWindow(FAs_animation);
		setBatchMode("hide");
		
		selectWindow(after_tubeness);
		setBatchMode("show");
		
		//wyskakujace okienko pozwala na to, by zatrymac dzialanie petli az uzytkownik kliknie 'OK',
		//dzieki czemu ma sie czas, by dobrac suwakiem odpowiedni threshold
		
		//dla pierwszego przebiegu dobiera automatycznie threshold, dla pozniejszych petl wybiera wartosc wczesniej wybrana przez uzytkownika
		if(first_run){
			setAutoThreshold("Default dark");
			run("Threshold...");
		}
		else {
			//set threshold musi byc po uruchomieniu thresholdu, inaczej program zmienial wartosci
			run("Threshold...");
			setThreshold(lower_threshold, upper_threshold);
			
		}
			
		waitForUser("Wybierz threshold", "Kliknij OK po wybraniu thresholdu. NIE klikaj 'Apply'");

		//przechwyca wybrane wartosci thresholdu przez uzytkownika,
		getThreshold(lower_threshold, upper_threshold);

		
		//probna analiza, ktora nie bedzie zapisywac zadnych wynikow, tylko sluzy do pokazania ktore kontakty zostana przez makro wychwycone
		run("Analyze Particles...", "size=40-Infinity pixel show=Ellipses exclude include");
		//zmiana nazwy okna
		results_of_analyze = "probny wynik";
		rename(results_of_analyze);
		
		//dodawanie obrazu do stacku obok oryginalnego zdjecia i puszczenie animacji,
		//by pokazywac ktore kontakty zogniskowane zostaly zaznaczone, by uzytkownik podjal decyzje,
		//czy threshold zostal dobrze dobrany, jezeli nie, to petla jest wykonywana ponownie i mozna zmienic threshold

		selectWindow(results_of_analyze);
		setThreshold(0, 254);
		run("Create Mask");
		run("Select All");
		run("Copy");

		selectWindow(FAs_animation);

		//jezeli petla juz wczesniej przeleciala, to usuwa pozostalosci w tym stacku i zostawia tylko pierwszy obraz
		while(nSlices != 1){
			setSlice(2);
			run("Delete Slice");
		}
		
		//dodaje czysty slice do stacku, wkleja tam maske i puszcza animacje
		run("Add Slice");
		setSlice(2);
		run("Paste");
		selectWindow(results_of_analyze);
		close();
		close("mask");
		selectWindow(FAs_animation);
		setBatchMode("show");
		doCommand("Start Animation [\\]");


		first_run = false;
		
	} while(getBoolean("Czy ponownie dobrac threshold?  'Cancel' zatrzymuje dzialanie makra. NIE klikaj 'Apply'", "Tak", "Nie"));
	
	selectWindow(FAs_animation);
	close();

	
	//zmienia jakie parametry beda mierzone przy wykorzystywaniu funkcji Analyze Particles,
	//poniewaz za chwile beda one zmieniane przy pomiarze powierzchni komorek,
	//dlatego trzeba je caly czas przywracac
	run("Set Measurements...", "area bounding standard fit add redirect=None decimal=3");
	
	selectWindow(after_tubeness);
	run("Threshold...");
	setThreshold(lower_threshold, upper_threshold);
	run("Analyze Particles...", "size=40-Infinity pixel show=Ellipses display exclude include summarize");

	//oblicza dlugosc kontaktow i wynik dopisuje do tabeli Results, korzystanie z walkosci major z dopasowania elipsy
	//wprowadza bledy - troche zaniza prawdziwa dlugosc kontaktow
	
	for (row=0; row<nResults; row++) {
		dlugosc = Math.sqrt(Math.sqr(getResult("Width", row)) + Math.sqr(getResult("Height", row)));
    	setResult("dlugosc", row, dlugosc);
	}
	updateResults();

	//zmiana nazwy tabeli z poszczegolnymi wymiarami kontaktow zogniskowanych
	table_name = "FAs of " + list[i];

	//na koncu nazwy pewnie bedzie /, wiec trzeba to usunac albo inaczej tabela sie nie zapisze
	if(endsWith(table_name, "/")){
		table_name = substring(table_name, 0, lastIndexOf(table_name, "/"));
	}

	//zapisywanie tabeli i zamykanie
	Table.rename("Results", table_name);
	Table.save(current_dir + table_name + ".csv");
	close(table_name);

	//na podstawie zdjecia z kanalu f-aktyny bedzie mierzona powierchnia komorek,
	//co posluzy do przeliczenia ilosci kontaktow na powierzchnie komorek

		
	//otwieranie oryginalnego obrazu kanalu z F-aktyna i zmiana nazwy, by pozniej w podsumowaniu wiedziec co to za warunek
	Factin_image = current_dir + File.separator + Factin;
	open(Factin_image);
	Factin_open = "area of " + list[i];
	rename(Factin_open);
	setBatchMode("show");

	//zmiana pomiarow by tylko mierzyc powierzchnie
	run("Set Measurements...", "area redirect=None decimal=3");
	
	selectWindow(Factin_open);
	setAutoThreshold("Default dark");
	run("Threshold...");
	
	//ten threshold powinien w wiekszosci pokrywac powierzchnie komorek ale nie musi calkowicie,
	//poniewaz w nastepnych krokach ewentualne male dziury w zanaczeniu powinny zostac wyeliminowane
	waitForUser("Wybierz threshold", "Dobierz prog tak aby wiekszosc powierzchni komorek zostala zaznaczona. Kliknij OK po wybraniu thresholdu");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	
	//usuwa pojedyncze piksele pochodzace z szumu, ktore przy kolejnym kroku wprowadzaja duzo bledu
	run("Erode");
	//wypelnia przerwy w zaznaczonej powierzchni komorek
	run("Maximum...", "radius=10");
	run("Minimum...", "radius=5");

	//mierzy powierzchnie komorek
	setAutoThreshold("Default");
	run("Threshold...");
	run("Analyze Particles...", "pixel summarize");
	
	
	//zamyka wszystkie okna ze zdjeciami, inaczej jakby byly jakies niezamkniete,
	//to w przypadku obrobki wielu zdjec moze dojsc do crashu ImageJ
	close("*");
	close("Threshold");


	//chwila na zlapanie oddechu miedzy kolejna seria zdjec
	wait(3000);
}