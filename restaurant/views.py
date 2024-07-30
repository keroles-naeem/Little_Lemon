# from django.http import HttpResponse
from django.shortcuts import render
from .forms import BookingForm
from .models import Menu



# Create your views here.
menu_items=Menu.objects.all()
items_dect={'menu':menu_items}
def home(request):
    return render(request, 'index.html')

def about(request):
    return render(request, 'about.html')
def menu(request):
    return render(request, 'menu.html',items_dect)

def display_menu_item(request,pk=None):
    if pk :
        menu_item={'menu_item':Menu.objects.get(pk=pk)}
    else : menu_item=''
        
    return render(request, 'menu_item.html',menu_item)

def book(request):
    form = BookingForm()
    if request.method == 'POST':
        form = BookingForm(request.POST)
        if form.is_valid():
            form.save()
    context = {'form':form}
    return render(request, 'book.html', context)

# Add your code here to create new views